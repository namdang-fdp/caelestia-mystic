import QtQuick
import Caelestia.Config
import qs.services

// Authentication and keyboard hints shown under the password field.
QtObject {
    id: root

    required property Pam pam

    readonly property bool error: !!msg
    readonly property string msg: {
        if (pam.fprint.state === Pam.Error)
            return qsTr("Fingerprint error: %1").arg(pam.fprint.message);
        if (pam.howdy.state === Pam.Error)
            return qsTr("Face unlock error: %1").arg(pam.howdy.message);
        if (pam.state === Pam.Error)
            return qsTr("Password error: %1").arg(pam.passwd.message);

        if (pam.fprint.state === Pam.Failed)
            return qsTr("Fingerprint not recognised (%1/%2)").arg(pam.fprint.tries).arg(GlobalConfig.lock.maxFprintTries);
        if (pam.howdy.state === Pam.Failed)
            return qsTr("Face not recognised (%1/%2)").arg(pam.howdy.tries).arg(GlobalConfig.lock.maxHowdyTries);

        if (pam.lockMessage)
            return pam.lockMessage;

        if (pam.state === Pam.Failed)
            return qsTr("Incorrect password");

        if (pam.state === Pam.MaxTries) {
            if (pam.fprint.available && pam.fprint.state !== Pam.MaxTries)
                return qsTr("Too many attempts. Use your fingerprint.");
            if (pam.howdy.available && pam.howdy.state !== Pam.MaxTries)
                return qsTr("Too many attempts. Use face unlock.");
            return qsTr("Too many attempts. Try again later.");
        }
        if (pam.fprint.state === Pam.MaxTries)
            return qsTr("Too many fingerprint attempts. Use your password.");
        if (pam.howdy.state === Pam.MaxTries)
            return qsTr("Too many face attempts. Use your password.");
        return "";
    }

    readonly property string hint: {
        const layout = Hypr.kbLayout !== Hypr.defaultKbLayout ? Hypr.kbLayoutFull : "";
        if (Hypr.capsLock && layout)
            return qsTr("Caps Lock is on · %1").arg(layout);
        if (Hypr.capsLock)
            return qsTr("Caps Lock is on");
        if (layout)
            return qsTr("Keyboard: %1").arg(layout);
        if (pam.fprint.available && pam.fprint.state !== Pam.MaxTries)
            return qsTr("Touch the fingerprint sensor or enter your password");
        if (pam.howdy.available && pam.howdy.state !== Pam.MaxTries)
            return qsTr("Press Enter for face unlock or type your password");
        return "";
    }
}
