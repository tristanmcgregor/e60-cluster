// Full-screen map mode: soft dark fades at the top and bottom of the panel, under the dials,
// so the clock, temperature, odometer and range stay legible over any map colours.
import QtQuick 2.14

Item {
    width: 1920
    height: 720
    Rectangle {
        width: parent.width; height: 190
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#e6000000" }
            GradientStop { position: 1.0; color: "#00000000" }
        }
    }
    Rectangle {
        y: parent.height - 170; width: parent.width; height: 170
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#e6000000" }
        }
    }
}
