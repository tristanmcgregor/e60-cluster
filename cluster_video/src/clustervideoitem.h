// ClusterVideoItem: draws the Android Auto instrument-cluster stream that our
// Open Headunit build forwards from the head unit (ClusterVideo.kt, TCP 8766).
//
// QML:  import ClusterVideo 1.0
//       ClusterVideoItem { host: "192.168.43.92"; sourceRect: Qt.rect(140, 0, 520, 480) }
#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickItem>
#include <QRect>
#include <QThread>

class StreamWorker;

class ClusterVideoItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QString host READ host WRITE setHost NOTIFY hostChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    // Part of the decoded frame to show (the phone draws inside AA's margins).
    Q_PROPERTY(QRect sourceRect READ sourceRect WRITE setSourceRect NOTIFY sourceRectChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    // True while frames keep arriving; false after ~2 s without one.
    Q_PROPERTY(bool streaming READ streaming NOTIFY streamingChanged)
    Q_PROPERTY(int framesDecoded READ framesDecoded NOTIFY framesDecodedChanged)

public:
    explicit ClusterVideoItem(QQuickItem *parent = nullptr);
    ~ClusterVideoItem() override;

    QString host() const { return m_host; }
    void setHost(const QString &host);
    int port() const { return m_port; }
    void setPort(int port);
    QRect sourceRect() const { return m_sourceRect; }
    void setSourceRect(const QRect &rect);
    bool connected() const { return m_connected; }
    bool streaming() const { return m_streaming; }
    int framesDecoded() const { return m_framesDecoded; }

signals:
    void hostChanged();
    void portChanged();
    void sourceRectChanged();
    void connectedChanged();
    void streamingChanged();
    void framesDecodedChanged();
    // to the worker thread
    void endpointChanged(const QString &host, int port, const QRect &crop);

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;
    void timerEvent(QTimerEvent *event) override;

private slots:
    void onFrame(const QImage &frame);
    void onConnected(bool connected);

private:
    void restartWorker();

    QString m_host;
    int m_port = 8766;
    QRect m_sourceRect;
    bool m_connected = false;
    bool m_streaming = false;
    int m_framesDecoded = 0;
    int m_staleTimer = 0;

    QThread m_thread;
    StreamWorker *m_worker = nullptr;

    QMutex m_frameLock;
    QImage m_frame;
    bool m_frameDirty = false;
};
