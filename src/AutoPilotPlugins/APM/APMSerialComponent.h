#pragma once

#include "VehicleComponent.h"

/// Vehicle setup component for configuring the autopilot's onboard serial ports
/// (SERIALn_PROTOCOL / SERIALn_BAUD / SERIALn_OPTIONS) with a live link indication.
class APMSerialComponent : public VehicleComponent
{
    Q_OBJECT

public:
    explicit APMSerialComponent(Vehicle *vehicle, AutoPilotPlugin *autopilot, QObject *parent = nullptr);

    QStringList setupCompleteChangedTriggerList() const final { return QStringList(); }

    QString name() const final { return _name; }
    QString description() const final { return tr("Configure the protocol and baud rate of the vehicle's onboard serial ports."); }
    QString iconResource() const final { return QStringLiteral("/qmlimages/ForwardingSupportIcon.svg"); }
    bool requiresSetup() const final { return false; }
    bool setupComplete() const final { return true; }
    QUrl setupSource() const final { return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMSerialComponent.qml")); }
    QUrl summaryQmlSource() const final { return QUrl(); }

private:
    const QString _name = tr("Serial Ports");
};
