/*
 * Copyright (C) by Cédric Bellegarde <gnumdk@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 */

#ifndef SYSTRAY_H
#define SYSTRAY_H

#include <QSystemTrayIcon>
#include <QQmlContext>

#include "accountmanager.h"
#include "tray/UserModel.h"

class QIcon;

namespace OCC {

#ifdef Q_OS_OSX
bool canOsXSendUserNotification();
void sendOsXUserNotification(const QString &title, const QString &message);
#endif

namespace Ui {
    class Systray;
}

/**
 * @brief The Systray class
 * @ingroup gui
 */
class Systray
    : public QSystemTrayIcon
{
    Q_OBJECT
public:
    static Systray *instance();
    virtual ~Systray() {};

    void create();
    void showMessage(const QString &title, const QString &message, MessageIcon icon = Information, int millisecondsTimeoutHint = 10000);
    void setToolTip(const QString &tip);
    bool isOpen();

    Q_INVOKABLE void pauseResumeSync();
    Q_INVOKABLE int calcTrayWindowX();
    Q_INVOKABLE int calcTrayWindowY();
    Q_INVOKABLE bool syncIsPaused();
    Q_INVOKABLE void setOpened();
    Q_INVOKABLE void setClosed();
    Q_INVOKABLE int screenIndex();

signals:
    void currentUserChanged();
    void openSettings();
    void openHelp();
    void shutdown();
    void pauseSync();
    void resumeSync();

    Q_INVOKABLE void hideWindow();
    Q_INVOKABLE void showWindow();

public slots:
    void slotNewUserSelected();

private:
    static Systray *_instance;
    Systray();
    bool _isOpen;
    bool _syncIsPaused;
    QQmlEngine *_trayEngine;
    QQmlComponent *_trayComponent;
    QQmlContext *_trayContext;
};

} // namespace OCC

#endif //SYSTRAY_H
