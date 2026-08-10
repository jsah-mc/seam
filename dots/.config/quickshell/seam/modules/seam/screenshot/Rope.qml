import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property vector2d start
    required property vector2d end
    property int segmentCount: 8
    property double segmentLen: 50
    property alias color: path.strokeColor
    property real thickness: 5
    readonly property Component p: PathLine {
        property vector2d pos
        property vector2d prevPos: pos
        property vector2d acc
        x: pos.x
        y: pos.y
    }
    readonly property double gravity: 3600
    readonly property int constraintRunCount: 10

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: path
            capStyle: ShapePath.RoundCap
            strokeColor: "#DAC99B"
            strokeWidth: root.thickness
            fillColor: "transparent"
        }
    }

    Component.onCompleted: () => {
        const xInc = (end.x - start.x) / segmentCount;
        const yInc = (end.y - start.y) / segmentCount;
        let i = 0;
        while (i < segmentCount) {
            path.pathElements.push(p.createObject(root, {
                pos: start.plus(Qt.vector2d(xInc * i, yInc * i)),
                acc: Qt.vector2d(0, root.gravity)
            }));
            i++;
        }
        path.pathElements[0].acc.y = 0;
        path.pathElements[segmentCount - 1].acc.y = 0;
        path.startX = path.pathElements[0].x;
        path.startY = path.pathElements[0].y;
    }

    FrameAnimation {
        running: true
        onTriggered: () => {
            const dt = frameTime;
            for (const point of path.pathElements.slice(1, root.segmentCount - 2)) {
                const newPos = point.pos.times(2.0).minus(point.prevPos).plus(point.acc.times(dt * dt));
                point.prevPos = point.pos;
                point.pos = newPos;
            }
            for (let i = 0; i < root.segmentCount - 1; i++) {
                const current = path.pathElements[i];
                const next = path.pathElements[i + 1];
                for (let j = 0; j < root.constraintRunCount; j++) {
                    const toNext = next.pos.minus(current.pos);
                    const distance = toNext.length();
                    const error = root.segmentLen - distance;
                    const pull = toNext.times(1.0 / distance).times(error).times(0.1);
                    if (i !== 0) {
                        current.pos = current.pos.minus(pull.times(0.5));
                        next.pos = next.pos.plus(pull.times(0.5));
                    } else {
                        next.pos = next.pos.plus(pull);
                    }
                }
            }
            path.pathElements[0].pos = root.start;
            path.pathElements[root.segmentCount - 1].pos = root.end;
            path.startX = path.pathElements[0].x;
            path.startY = path.pathElements[0].y;
        }
    }
}
