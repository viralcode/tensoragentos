/*
 * TerminalEmulator — VT100/xterm ANSI escape sequence parser + screen buffer
 *
 * Maintains a grid of character cells (rows × cols), each with:
 *   • Unicode character
 *   • Foreground/background color (256-color + true-color support)
 *   • Bold, underline, inverse, dim attributes
 *
 * Handles standard VT100/xterm escape sequences:
 *   • CSI sequences: cursor movement, erase, SGR (colors/attrs)
 *   • OSC sequences: window title
 *   • Scroll regions, line insert/delete
 *   • Alternate screen buffer (for nano, vim, htop, etc.)
 */

#ifndef TERMINALEMULATOR_H
#define TERMINALEMULATOR_H

#include <QObject>
#include <QVector>
#include <QString>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDebug>
#include <QTimer>

// ═══════════════════════════════════════════════
// Terminal Cell — single character with attributes
// ═══════════════════════════════════════════════

struct TermCell {
    QChar ch = ' ';
    int fg = 7;        // Default: white (standard color index or -1 for default)
    int bg = 0;        // Default: black
    bool fgDefault = true;
    bool bgDefault = true;
    bool bold = false;
    bool dim = false;
    bool underline = false;
    bool inverse = false;
    bool italic = false;
    bool strikethrough = false;
    // For 24-bit color
    int fgR = -1, fgG = -1, fgB = -1;
    int bgR = -1, bgG = -1, bgB = -1;
};


class TerminalEmulator : public QObject {
    Q_OBJECT

    Q_PROPERTY(int cursorRow READ cursorRow NOTIFY screenChanged)
    Q_PROPERTY(int cursorCol READ cursorCol NOTIFY screenChanged)
    Q_PROPERTY(bool cursorVisible READ cursorVisible NOTIFY screenChanged)

public:
    explicit TerminalEmulator(QObject *parent = nullptr)
        : QObject(parent), m_rows(24), m_cols(80),
          m_cursorRow(0), m_cursorCol(0),
          m_savedRow(0), m_savedCol(0),
          m_scrollTop(0), m_scrollBottom(23),
          m_cursorVisible(true),
          m_altScreen(false),
          m_parseState(Normal),
          m_originMode(false),
          m_autoWrap(true),
          m_bracketedPaste(false)
    {
        initScreen(m_screen, m_rows, m_cols);
        initScreen(m_altScreenBuf, m_rows, m_cols);

        // Batch screen updates: coalesce rapid data bursts into single repaints
        m_updateTimer.setSingleShot(true);
        m_updateTimer.setInterval(16);  // ~60fps
        connect(&m_updateTimer, &QTimer::timeout, this, [this]() {
            emit screenChanged();
        });
    }

    Q_INVOKABLE void init(int rows, int cols) {
        m_rows = rows;
        m_cols = cols;
        m_scrollBottom = rows - 1;
        initScreen(m_screen, rows, cols);
        initScreen(m_altScreenBuf, rows, cols);
        m_cursorRow = 0;
        m_cursorCol = 0;
        scheduleUpdate();
    }

    Q_INVOKABLE void resize(int rows, int cols) {
        if (rows == m_rows && cols == m_cols) return;

        // Resize main screen
        resizeScreen(m_screen, m_scrollback, m_rows, m_cols, rows, cols, m_cursorRow);

        // Resize alt screen
        int dummyCursor = 0;
        QVector<QVector<TermCell>> dummyScrollback;
        resizeScreen(m_altScreenBuf, dummyScrollback, m_rows, m_cols, rows, cols, dummyCursor);

        m_rows = rows;
        m_cols = cols;
        m_scrollBottom = rows - 1;
        if (m_scrollTop >= rows) m_scrollTop = 0;
        if (m_cursorRow >= rows) m_cursorRow = rows - 1;
        if (m_cursorCol >= cols) m_cursorCol = cols - 1;

        scheduleUpdate();
    }

    // Process raw bytes from the PTY
    Q_INVOKABLE void processData(const QByteArray &data) {
        for (int i = 0; i < data.size(); i++) {
            unsigned char c = static_cast<unsigned char>(data[i]);
            processChar(c, data, i);
        }
        scheduleUpdate();
    }

    // Get the screen content as JSON for QML rendering
    Q_INVOKABLE QString getScreenJSON() {
        QJsonArray screenArr;
        auto &scr = currentScreen();

        for (int r = 0; r < m_rows && r < scr.size(); r++) {
            QJsonArray rowArr;
            for (int c = 0; c < m_cols && c < scr[r].size(); c++) {
                const TermCell &cell = scr[r][c];
                QJsonObject cellObj;
                cellObj["c"] = QString(cell.ch);

                // Compact: only include non-default attributes
                if (!cell.fgDefault) {
                    if (cell.fgR >= 0) {
                        cellObj["fg"] = QString("#%1%2%3")
                            .arg(cell.fgR, 2, 16, QChar('0'))
                            .arg(cell.fgG, 2, 16, QChar('0'))
                            .arg(cell.fgB, 2, 16, QChar('0'));
                    } else {
                        cellObj["fi"] = cell.fg;
                    }
                }
                if (!cell.bgDefault) {
                    if (cell.bgR >= 0) {
                        cellObj["bg"] = QString("#%1%2%3")
                            .arg(cell.bgR, 2, 16, QChar('0'))
                            .arg(cell.bgG, 2, 16, QChar('0'))
                            .arg(cell.bgB, 2, 16, QChar('0'));
                    } else {
                        cellObj["bi"] = cell.bg;
                    }
                }
                if (cell.bold) cellObj["b"] = true;
                if (cell.dim) cellObj["d"] = true;
                if (cell.underline) cellObj["u"] = true;
                if (cell.inverse) cellObj["i"] = true;
                if (cell.italic) cellObj["it"] = true;

                rowArr.append(cellObj);
            }
            screenArr.append(rowArr);
        }

        return QString::fromUtf8(QJsonDocument(screenArr).toJson(QJsonDocument::Compact));
    }

    // Optimized: get screen as a compact line-based format for QML
    Q_INVOKABLE QStringList getScreenLines() {
        QStringList lines;
        auto &scr = currentScreen();

        for (int r = 0; r < m_rows && r < scr.size(); r++) {
            QString line;
            for (int c = 0; c < m_cols && c < scr[r].size(); c++) {
                line += scr[r][c].ch;
            }
            // Trim trailing spaces
            while (line.endsWith(' ')) line.chop(1);
            lines.append(line);
        }
        return lines;
    }

    // Get color/attribute data for a specific row as compact string
    // Format: "fg,bg,attrs;" per cell where attrs is a bitmask
    Q_INVOKABLE QString getRowAttrs(int row) {
        auto &scr = currentScreen();
        if (row < 0 || row >= scr.size()) return "";

        QString result;
        const auto &rowData = scr[row];

        for (int c = 0; c < m_cols && c < rowData.size(); c++) {
            const TermCell &cell = rowData[c];

            // Encode foreground
            if (cell.fgR >= 0) {
                result += QString("r%1,%2,%3").arg(cell.fgR).arg(cell.fgG).arg(cell.fgB);
            } else if (!cell.fgDefault) {
                result += QString::number(cell.fg);
            } else {
                result += "-";
            }
            result += ",";

            // Encode background
            if (cell.bgR >= 0) {
                result += QString("r%1,%2,%3").arg(cell.bgR).arg(cell.bgG).arg(cell.bgB);
            } else if (!cell.bgDefault) {
                result += QString::number(cell.bg);
            } else {
                result += "-";
            }

            // Encode attributes as bitmask
            int attrs = 0;
            if (cell.bold) attrs |= 1;
            if (cell.dim) attrs |= 2;
            if (cell.underline) attrs |= 4;
            if (cell.inverse) attrs |= 8;
            if (cell.italic) attrs |= 16;
            if (cell.strikethrough) attrs |= 32;

            if (attrs) {
                result += "," + QString::number(attrs);
            }

            result += ";";
        }

        return result;
    }

    // Get scrollback buffer lines
    Q_INVOKABLE int scrollbackSize() {
        return m_scrollback.size();
    }

    Q_INVOKABLE QString getScrollbackLine(int index) {
        if (index < 0 || index >= m_scrollback.size()) return "";
        QString line;
        for (const auto &cell : m_scrollback[index]) {
            line += cell.ch;
        }
        while (line.endsWith(' ')) line.chop(1);
        return line;
    }

    int cursorRow() const { return m_cursorRow; }
    int cursorCol() const { return m_cursorCol; }
    bool cursorVisible() const { return m_cursorVisible; }

signals:
    void screenChanged();
    void titleChanged(const QString &title);
    void bellRang();

private:
    int m_rows, m_cols;
    int m_cursorRow, m_cursorCol;
    int m_savedRow, m_savedCol;
    int m_scrollTop, m_scrollBottom;
    bool m_cursorVisible;
    bool m_altScreen;
    bool m_originMode;
    bool m_autoWrap;
    bool m_bracketedPaste;

    TermCell m_currentAttr;  // Current SGR attributes for new characters
    QTimer m_updateTimer;

    // Screen buffers
    QVector<QVector<TermCell>> m_screen;
    QVector<QVector<TermCell>> m_altScreenBuf;
    QVector<QVector<TermCell>> m_scrollback;  // Scrollback buffer (main screen only)

    static const int MAX_SCROLLBACK = 5000;

    QVector<QVector<TermCell>> &currentScreen() {
        return m_altScreen ? m_altScreenBuf : m_screen;
    }

    // ── Parse State Machine ──
    enum ParseState {
        Normal,
        Escape,        // Got ESC
        CSI,           // Got ESC[
        OSC,           // Got ESC]
        OSCString,     // Reading OSC string
        DCS,           // Device Control String
        CharsetG0,     // ESC (
        CharsetG1,     // ESC )
    };

    ParseState m_parseState;
    QString m_csiParams;
    QString m_oscString;

    void scheduleUpdate() {
        if (!m_updateTimer.isActive()) {
            m_updateTimer.start();
        }
    }

    void initScreen(QVector<QVector<TermCell>> &screen, int rows, int cols) {
        screen.resize(rows);
        for (int r = 0; r < rows; r++) {
            screen[r].resize(cols);
            for (int c = 0; c < cols; c++) {
                screen[r][c] = TermCell();
            }
        }
    }

    void resizeScreen(QVector<QVector<TermCell>> &screen,
                      QVector<QVector<TermCell>> &scrollback,
                      int oldRows, int oldCols, int newRows, int newCols,
                      int &cursorRow) {
        // Resize columns for existing rows
        for (int r = 0; r < screen.size(); r++) {
            screen[r].resize(newCols);
            for (int c = oldCols; c < newCols; c++) {
                screen[r][c] = TermCell();
            }
        }

        // Add or remove rows
        if (newRows > screen.size()) {
            // Add rows at bottom
            int toAdd = newRows - screen.size();
            // First pull from scrollback
            while (toAdd > 0 && !scrollback.isEmpty()) {
                screen.prepend(scrollback.takeLast());
                if (screen.first().size() < newCols) {
                    screen.first().resize(newCols);
                }
                cursorRow++;
                toAdd--;
            }
            // Then add blank rows
            while (screen.size() < newRows) {
                QVector<TermCell> row(newCols);
                screen.append(row);
            }
        } else if (newRows < screen.size()) {
            // Push excess rows to scrollback
            while (screen.size() > newRows) {
                scrollback.append(screen.takeFirst());
                cursorRow--;
                if (scrollback.size() > MAX_SCROLLBACK) {
                    scrollback.removeFirst();
                }
            }
            if (cursorRow < 0) cursorRow = 0;
        }
    }

    // Clamp cursor to valid range
    void clampCursor() {
        if (m_cursorRow < 0) m_cursorRow = 0;
        if (m_cursorRow >= m_rows) m_cursorRow = m_rows - 1;
        if (m_cursorCol < 0) m_cursorCol = 0;
        if (m_cursorCol >= m_cols) m_cursorCol = m_cols - 1;
    }

    // Scroll the region up by one line
    void scrollUp(int top, int bottom) {
        auto &scr = currentScreen();
        if (top < 0 || bottom >= m_rows || top >= bottom) return;

        // If scrolling the whole screen in main buffer, save to scrollback
        if (!m_altScreen && top == 0) {
            m_scrollback.append(scr[0]);
            if (m_scrollback.size() > MAX_SCROLLBACK) {
                m_scrollback.removeFirst();
            }
        }

        // Shift rows up
        for (int r = top; r < bottom; r++) {
            scr[r] = scr[r + 1];
        }

        // Clear the bottom row
        scr[bottom].fill(TermCell(), m_cols);
        if (scr[bottom].size() < m_cols) {
            scr[bottom].resize(m_cols);
        }
    }

    // Scroll the region down by one line
    void scrollDown(int top, int bottom) {
        auto &scr = currentScreen();
        if (top < 0 || bottom >= m_rows || top >= bottom) return;

        for (int r = bottom; r > top; r--) {
            scr[r] = scr[r - 1];
        }

        scr[top].fill(TermCell(), m_cols);
        if (scr[top].size() < m_cols) {
            scr[top].resize(m_cols);
        }
    }

    // Put a character at the current cursor position
    void putChar(QChar ch) {
        auto &scr = currentScreen();

        if (m_cursorCol >= m_cols) {
            if (m_autoWrap) {
                m_cursorCol = 0;
                m_cursorRow++;
                if (m_cursorRow > m_scrollBottom) {
                    m_cursorRow = m_scrollBottom;
                    scrollUp(m_scrollTop, m_scrollBottom);
                }
            } else {
                m_cursorCol = m_cols - 1;
            }
        }

        if (m_cursorRow >= 0 && m_cursorRow < scr.size() &&
            m_cursorCol >= 0 && m_cursorCol < scr[m_cursorRow].size()) {
            TermCell &cell = scr[m_cursorRow][m_cursorCol];
            cell.ch = ch;
            cell.fg = m_currentAttr.fg;
            cell.bg = m_currentAttr.bg;
            cell.fgDefault = m_currentAttr.fgDefault;
            cell.bgDefault = m_currentAttr.bgDefault;
            cell.bold = m_currentAttr.bold;
            cell.dim = m_currentAttr.dim;
            cell.underline = m_currentAttr.underline;
            cell.inverse = m_currentAttr.inverse;
            cell.italic = m_currentAttr.italic;
            cell.strikethrough = m_currentAttr.strikethrough;
            cell.fgR = m_currentAttr.fgR;
            cell.fgG = m_currentAttr.fgG;
            cell.fgB = m_currentAttr.fgB;
            cell.bgR = m_currentAttr.bgR;
            cell.bgG = m_currentAttr.bgG;
            cell.bgB = m_currentAttr.bgB;
        }

        m_cursorCol++;
    }

    // ════════════════════════════════════════════════
    // Main character processor (state machine)
    // ════════════════════════════════════════════════

    void processChar(unsigned char c, const QByteArray &data, int &pos) {
        switch (m_parseState) {
        case Normal:
            if (c == 0x1b) {  // ESC
                m_parseState = Escape;
            } else if (c == '\n') {
                m_cursorRow++;
                if (m_cursorRow > m_scrollBottom) {
                    m_cursorRow = m_scrollBottom;
                    scrollUp(m_scrollTop, m_scrollBottom);
                }
            } else if (c == '\r') {
                m_cursorCol = 0;
            } else if (c == '\b') {
                if (m_cursorCol > 0) m_cursorCol--;
            } else if (c == '\t') {
                m_cursorCol = ((m_cursorCol / 8) + 1) * 8;
                if (m_cursorCol >= m_cols) m_cursorCol = m_cols - 1;
            } else if (c == '\a') {
                emit bellRang();
            } else if (c == 0x0e || c == 0x0f) {
                // SI/SO — charset switching, ignore
            } else if (c >= 0x20) {
                // Handle UTF-8 multi-byte characters
                if (c >= 0x80) {
                    QByteArray utf8Bytes;
                    utf8Bytes.append(c);
                    int extraBytes = 0;
                    if ((c & 0xE0) == 0xC0) extraBytes = 1;
                    else if ((c & 0xF0) == 0xE0) extraBytes = 2;
                    else if ((c & 0xF8) == 0xF0) extraBytes = 3;

                    for (int j = 0; j < extraBytes && (pos + 1) < data.size(); j++) {
                        pos++;
                        utf8Bytes.append(static_cast<unsigned char>(data[pos]));
                    }

                    QString str = QString::fromUtf8(utf8Bytes);
                    if (!str.isEmpty()) {
                        putChar(str[0]);
                    }
                } else {
                    putChar(QChar(c));
                }
            }
            break;

        case Escape:
            if (c == '[') {
                m_parseState = CSI;
                m_csiParams.clear();
            } else if (c == ']') {
                m_parseState = OSC;
                m_oscString.clear();
            } else if (c == '(') {
                m_parseState = CharsetG0;
            } else if (c == ')') {
                m_parseState = CharsetG1;
            } else if (c == 'P') {
                m_parseState = DCS;
                m_oscString.clear();
            } else if (c == '7') {
                // Save cursor
                m_savedRow = m_cursorRow;
                m_savedCol = m_cursorCol;
                m_parseState = Normal;
            } else if (c == '8') {
                // Restore cursor
                m_cursorRow = m_savedRow;
                m_cursorCol = m_savedCol;
                clampCursor();
                m_parseState = Normal;
            } else if (c == 'D') {
                // Index (scroll up if at bottom)
                m_cursorRow++;
                if (m_cursorRow > m_scrollBottom) {
                    m_cursorRow = m_scrollBottom;
                    scrollUp(m_scrollTop, m_scrollBottom);
                }
                m_parseState = Normal;
            } else if (c == 'M') {
                // Reverse Index (scroll down if at top)
                m_cursorRow--;
                if (m_cursorRow < m_scrollTop) {
                    m_cursorRow = m_scrollTop;
                    scrollDown(m_scrollTop, m_scrollBottom);
                }
                m_parseState = Normal;
            } else if (c == 'E') {
                // Next Line
                m_cursorCol = 0;
                m_cursorRow++;
                if (m_cursorRow > m_scrollBottom) {
                    m_cursorRow = m_scrollBottom;
                    scrollUp(m_scrollTop, m_scrollBottom);
                }
                m_parseState = Normal;
            } else if (c == 'c') {
                // Full reset
                resetTerminal();
                m_parseState = Normal;
            } else if (c == '=') {
                // Application keypad mode
                m_parseState = Normal;
            } else if (c == '>') {
                // Normal keypad mode
                m_parseState = Normal;
            } else {
                m_parseState = Normal;
            }
            break;

        case CSI:
            if (c >= 0x30 && c <= 0x3f) {
                // Parameter byte
                m_csiParams += QChar(c);
            } else if (c >= 0x20 && c <= 0x2f) {
                // Intermediate byte
                m_csiParams += QChar(c);
            } else if (c >= 0x40 && c <= 0x7e) {
                // Final byte — execute the CSI sequence
                handleCSI(c);
                m_parseState = Normal;
            } else {
                // Invalid — abort sequence
                m_parseState = Normal;
            }
            break;

        case OSC:
            if (c == 0x1b) {
                // Check for ST (ESC \)
                m_parseState = OSCString;
            } else if (c == '\a' || c == 0x9c) {
                // BEL or ST terminates OSC
                handleOSC();
                m_parseState = Normal;
            } else {
                m_oscString += QChar(c);
            }
            break;

        case OSCString:
            if (c == '\\') {
                handleOSC();
            }
            m_parseState = Normal;
            break;

        case DCS:
            // Consume until ST
            if (c == 0x1b) {
                m_parseState = OSCString;  // Reuse for ST detection
            } else if (c == 0x9c) {
                m_parseState = Normal;
            }
            break;

        case CharsetG0:
        case CharsetG1:
            // Consume the charset designator character and return to normal
            m_parseState = Normal;
            break;
        }
    }

    // ════════════════════════════════════════════════
    // CSI Sequence Handler
    // ════════════════════════════════════════════════

    void handleCSI(unsigned char finalByte) {
        // Parse parameters (semicolon-separated integers)
        QVector<int> params;
        QString currentParam;
        bool hasQuestion = m_csiParams.startsWith('?');
        bool hasGt = m_csiParams.startsWith('>');
        bool hasExcl = m_csiParams.startsWith('!');
        QString paramStr = m_csiParams;
        if (hasQuestion || hasGt || hasExcl) paramStr = paramStr.mid(1);

        for (int i = 0; i < paramStr.length(); i++) {
            if (paramStr[i] == ';') {
                params.append(currentParam.isEmpty() ? 0 : currentParam.toInt());
                currentParam.clear();
            } else if (paramStr[i] == ' ') {
                // Space before final byte (e.g., "CSI 2 q" for cursor style)
                continue;
            } else {
                currentParam += paramStr[i];
            }
        }
        if (!currentParam.isEmpty() || paramStr.endsWith(';')) {
            params.append(currentParam.isEmpty() ? 0 : currentParam.toInt());
        }
        if (params.isEmpty()) params.append(0);

        auto &scr = currentScreen();

        switch (finalByte) {
        case 'A':  // CUU — Cursor Up
            m_cursorRow -= qMax(1, params[0]);
            clampCursor();
            break;

        case 'B':  // CUD — Cursor Down
            m_cursorRow += qMax(1, params[0]);
            clampCursor();
            break;

        case 'C':  // CUF — Cursor Forward
            m_cursorCol += qMax(1, params[0]);
            clampCursor();
            break;

        case 'D':  // CUB — Cursor Back
            m_cursorCol -= qMax(1, params[0]);
            clampCursor();
            break;

        case 'E':  // CNL — Cursor Next Line
            m_cursorCol = 0;
            m_cursorRow += qMax(1, params[0]);
            clampCursor();
            break;

        case 'F':  // CPL — Cursor Previous Line
            m_cursorCol = 0;
            m_cursorRow -= qMax(1, params[0]);
            clampCursor();
            break;

        case 'G':  // CHA — Cursor Horizontal Absolute
            m_cursorCol = qMax(1, params[0]) - 1;
            clampCursor();
            break;

        case 'H':  // CUP — Cursor Position
        case 'f':  // HVP — same
        {
            int row = params.size() > 0 ? qMax(1, params[0]) - 1 : 0;
            int col = params.size() > 1 ? qMax(1, params[1]) - 1 : 0;
            m_cursorRow = row;
            m_cursorCol = col;
            clampCursor();
            break;
        }

        case 'J':  // ED — Erase in Display
        {
            int mode = params[0];
            if (mode == 0) {
                // Erase from cursor to end
                clearRange(m_cursorRow, m_cursorCol, m_rows - 1, m_cols - 1);
            } else if (mode == 1) {
                // Erase from start to cursor
                clearRange(0, 0, m_cursorRow, m_cursorCol);
            } else if (mode == 2 || mode == 3) {
                // Erase entire display
                clearRange(0, 0, m_rows - 1, m_cols - 1);
                if (mode == 3) {
                    m_scrollback.clear();
                }
            }
            break;
        }

        case 'K':  // EL — Erase in Line
        {
            int mode = params[0];
            if (mode == 0) {
                // Erase from cursor to end of line
                clearRange(m_cursorRow, m_cursorCol, m_cursorRow, m_cols - 1);
            } else if (mode == 1) {
                // Erase from start to cursor
                clearRange(m_cursorRow, 0, m_cursorRow, m_cursorCol);
            } else if (mode == 2) {
                // Erase entire line
                clearRange(m_cursorRow, 0, m_cursorRow, m_cols - 1);
            }
            break;
        }

        case 'L':  // IL — Insert Lines
        {
            int count = qMax(1, params[0]);
            for (int i = 0; i < count; i++) {
                if (m_cursorRow <= m_scrollBottom) {
                    scrollDown(m_cursorRow, m_scrollBottom);
                }
            }
            break;
        }

        case 'M':  // DL — Delete Lines
        {
            int count = qMax(1, params[0]);
            for (int i = 0; i < count; i++) {
                if (m_cursorRow <= m_scrollBottom) {
                    scrollUp(m_cursorRow, m_scrollBottom);
                }
            }
            break;
        }

        case 'P':  // DCH — Delete Characters
        {
            int count = qMax(1, params[0]);
            if (m_cursorRow < scr.size()) {
                auto &row = scr[m_cursorRow];
                for (int i = 0; i < count && m_cursorCol < row.size(); i++) {
                    row.remove(m_cursorCol, 1);
                    row.append(TermCell());
                }
            }
            break;
        }

        case '@':  // ICH — Insert Characters
        {
            int count = qMax(1, params[0]);
            if (m_cursorRow < scr.size()) {
                auto &row = scr[m_cursorRow];
                for (int i = 0; i < count; i++) {
                    row.insert(m_cursorCol, TermCell());
                    if (row.size() > m_cols) row.resize(m_cols);
                }
            }
            break;
        }

        case 'X':  // ECH — Erase Characters
        {
            int count = qMax(1, params[0]);
            clearRange(m_cursorRow, m_cursorCol, m_cursorRow, m_cursorCol + count - 1);
            break;
        }

        case 'S':  // SU — Scroll Up
        {
            int count = qMax(1, params[0]);
            for (int i = 0; i < count; i++) {
                scrollUp(m_scrollTop, m_scrollBottom);
            }
            break;
        }

        case 'T':  // SD — Scroll Down
        {
            int count = qMax(1, params[0]);
            for (int i = 0; i < count; i++) {
                scrollDown(m_scrollTop, m_scrollBottom);
            }
            break;
        }

        case 'd':  // VPA — Line Position Absolute
            m_cursorRow = qMax(1, params[0]) - 1;
            clampCursor();
            break;

        case 'r':  // DECSTBM — Set Scrolling Region
        {
            int top = params.size() > 0 && params[0] > 0 ? params[0] - 1 : 0;
            int bot = params.size() > 1 && params[1] > 0 ? params[1] - 1 : m_rows - 1;
            if (top < bot && bot < m_rows) {
                m_scrollTop = top;
                m_scrollBottom = bot;
            }
            m_cursorRow = m_originMode ? m_scrollTop : 0;
            m_cursorCol = 0;
            break;
        }

        case 'm':  // SGR — Select Graphic Rendition
            handleSGR(params);
            break;

        case 'h':  // SM — Set Mode
            if (hasQuestion) handleDECMode(params, true);
            break;

        case 'l':  // RM — Reset Mode
            if (hasQuestion) handleDECMode(params, false);
            break;

        case 'n':  // DSR — Device Status Report
            if (params[0] == 6) {
                // Report cursor position (response: ESC[row;colR)
                // This would need to write back to the PTY
                // Handled via signal if needed
            }
            break;

        case 'c':  // DA — Device Attributes
            // Response would be written back to PTY
            break;

        case 's':  // SCP — Save Cursor Position
            m_savedRow = m_cursorRow;
            m_savedCol = m_cursorCol;
            break;

        case 'u':  // RCP — Restore Cursor Position
            m_cursorRow = m_savedRow;
            m_cursorCol = m_savedCol;
            clampCursor();
            break;

        case 'q':  // DECSCUSR — Set Cursor Style
            // Could change cursor style (block, underline, bar)
            break;

        case 't':  // Window manipulation — mostly ignored
            break;

        default:
            break;
        }
    }

    // ════════════════════════════════════════════════
    // SGR (Select Graphic Rendition)
    // ════════════════════════════════════════════════

    void handleSGR(const QVector<int> &params) {
        for (int i = 0; i < params.size(); i++) {
            int p = params[i];

            if (p == 0) {
                // Reset
                m_currentAttr = TermCell();
            } else if (p == 1) {
                m_currentAttr.bold = true;
            } else if (p == 2) {
                m_currentAttr.dim = true;
            } else if (p == 3) {
                m_currentAttr.italic = true;
            } else if (p == 4) {
                m_currentAttr.underline = true;
            } else if (p == 7) {
                m_currentAttr.inverse = true;
            } else if (p == 9) {
                m_currentAttr.strikethrough = true;
            } else if (p == 21 || p == 22) {
                m_currentAttr.bold = false;
                m_currentAttr.dim = false;
            } else if (p == 23) {
                m_currentAttr.italic = false;
            } else if (p == 24) {
                m_currentAttr.underline = false;
            } else if (p == 27) {
                m_currentAttr.inverse = false;
            } else if (p == 29) {
                m_currentAttr.strikethrough = false;
            } else if (p >= 30 && p <= 37) {
                // Standard FG colors
                m_currentAttr.fg = p - 30;
                m_currentAttr.fgDefault = false;
                m_currentAttr.fgR = -1;
            } else if (p == 38) {
                // Extended FG color
                if (i + 1 < params.size()) {
                    if (params[i + 1] == 5 && i + 2 < params.size()) {
                        // 256-color
                        m_currentAttr.fg = params[i + 2];
                        m_currentAttr.fgDefault = false;
                        m_currentAttr.fgR = -1;
                        i += 2;
                    } else if (params[i + 1] == 2 && i + 4 < params.size()) {
                        // True color RGB
                        m_currentAttr.fgR = params[i + 2];
                        m_currentAttr.fgG = params[i + 3];
                        m_currentAttr.fgB = params[i + 4];
                        m_currentAttr.fgDefault = false;
                        i += 4;
                    }
                }
            } else if (p == 39) {
                // Default FG
                m_currentAttr.fg = 7;
                m_currentAttr.fgDefault = true;
                m_currentAttr.fgR = -1;
            } else if (p >= 40 && p <= 47) {
                // Standard BG colors
                m_currentAttr.bg = p - 40;
                m_currentAttr.bgDefault = false;
                m_currentAttr.bgR = -1;
            } else if (p == 48) {
                // Extended BG color
                if (i + 1 < params.size()) {
                    if (params[i + 1] == 5 && i + 2 < params.size()) {
                        m_currentAttr.bg = params[i + 2];
                        m_currentAttr.bgDefault = false;
                        m_currentAttr.bgR = -1;
                        i += 2;
                    } else if (params[i + 1] == 2 && i + 4 < params.size()) {
                        m_currentAttr.bgR = params[i + 2];
                        m_currentAttr.bgG = params[i + 3];
                        m_currentAttr.bgB = params[i + 4];
                        m_currentAttr.bgDefault = false;
                        i += 4;
                    }
                }
            } else if (p == 49) {
                // Default BG
                m_currentAttr.bg = 0;
                m_currentAttr.bgDefault = true;
                m_currentAttr.bgR = -1;
            } else if (p >= 90 && p <= 97) {
                // Bright FG colors
                m_currentAttr.fg = p - 90 + 8;
                m_currentAttr.fgDefault = false;
                m_currentAttr.fgR = -1;
            } else if (p >= 100 && p <= 107) {
                // Bright BG colors
                m_currentAttr.bg = p - 100 + 8;
                m_currentAttr.bgDefault = false;
                m_currentAttr.bgR = -1;
            }
        }
    }

    // ════════════════════════════════════════════════
    // DEC Private Mode (DECSET/DECRST)
    // ════════════════════════════════════════════════

    void handleDECMode(const QVector<int> &params, bool set) {
        for (int p : params) {
            switch (p) {
            case 1:    // DECCKM — Cursor keys mode (application vs normal)
                // Handled in QML for key encoding
                break;
            case 6:    // DECOM — Origin mode
                m_originMode = set;
                m_cursorRow = m_originMode ? m_scrollTop : 0;
                m_cursorCol = 0;
                break;
            case 7:    // DECAWM — Auto-wrap mode
                m_autoWrap = set;
                break;
            case 12:   // Cursor blink
                break;
            case 25:   // DECTCEM — Text cursor enable mode
                m_cursorVisible = set;
                break;
            case 47:   // Alternate screen buffer (old style)
                switchScreen(set);
                break;
            case 1000: // Mouse tracking
            case 1002: // Button event mouse
            case 1003: // Any event mouse
            case 1006: // SGR mouse mode
                break;
            case 1049: // Alternate screen buffer (new style, save/restore cursor)
                if (set) {
                    m_savedRow = m_cursorRow;
                    m_savedCol = m_cursorCol;
                }
                switchScreen(set);
                if (!set) {
                    m_cursorRow = m_savedRow;
                    m_cursorCol = m_savedCol;
                    clampCursor();
                }
                break;
            case 2004: // Bracketed paste mode
                m_bracketedPaste = set;
                break;
            }
        }
    }

    // Switch between main and alternate screen buffer
    void switchScreen(bool toAlt) {
        if (toAlt == m_altScreen) return;
        m_altScreen = toAlt;
        if (toAlt) {
            // Clear alt screen
            initScreen(m_altScreenBuf, m_rows, m_cols);
        }
        m_scrollTop = 0;
        m_scrollBottom = m_rows - 1;
    }

    // Clear a range of cells
    void clearRange(int r1, int c1, int r2, int c2) {
        auto &scr = currentScreen();
        for (int r = r1; r <= r2 && r < scr.size(); r++) {
            int startCol = (r == r1) ? c1 : 0;
            int endCol = (r == r2) ? c2 : m_cols - 1;
            for (int c = startCol; c <= endCol && c < scr[r].size(); c++) {
                scr[r][c] = TermCell();
            }
        }
    }

    // Handle OSC (Operating System Command) sequences
    void handleOSC() {
        if (m_oscString.isEmpty()) return;

        int semicolonPos = m_oscString.indexOf(';');
        if (semicolonPos < 0) return;

        int cmd = m_oscString.left(semicolonPos).toInt();
        QString value = m_oscString.mid(semicolonPos + 1);

        if (cmd == 0 || cmd == 2) {
            // Set window title
            emit titleChanged(value);
        }
        // Other OSC commands (colors, hyperlinks, etc.) can be added
    }

    void resetTerminal() {
        m_currentAttr = TermCell();
        m_cursorRow = 0;
        m_cursorCol = 0;
        m_scrollTop = 0;
        m_scrollBottom = m_rows - 1;
        m_cursorVisible = true;
        m_originMode = false;
        m_autoWrap = true;
        m_altScreen = false;
        initScreen(m_screen, m_rows, m_cols);
        initScreen(m_altScreenBuf, m_rows, m_cols);
        m_scrollback.clear();
    }
};

#endif // TERMINALEMULATOR_H
