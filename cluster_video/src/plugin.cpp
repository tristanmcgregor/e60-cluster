// QML module "ClusterVideo 1.0". Installed to /etc/qml/ClusterVideo/ on the cluster
// (/etc/qml is already on QML2_IMPORT_PATH in /etc/qtenv.sh).
#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "clustervideoitem.h"

class ClusterVideoPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<ClusterVideoItem>(uri, 1, 0, "ClusterVideoItem");
    }
};

#include "plugin.moc"
