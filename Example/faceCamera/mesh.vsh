precision highp float;
attribute vec4 position;
attribute vec3 normal;
attribute vec2 inputTextureCoordinate;
varying vec2 textureCoordinate;
uniform mat4 viewProjectionMatrix;
uniform float screenRatio;

struct MeshDistortionType {
    int type;
    float strength;
    vec2 point;
    float radius;
    int direction;
    float faceDegree;
    float faceRatio;
};

uniform MeshDistortionType items[30];

vec4 distortedPosition(vec4 currentPosition) {
    float useScreenRatio = screenRatio;
    vec4 newPosition = currentPosition;
    if (newPosition.x == -1.0 || newPosition.y == -1.0 || newPosition.x == 1.0 || newPosition.y == 1.0) {
        return newPosition;
    }
    for (int i = 0; i < 30; i++) {
        MeshDistortionType item = items[i];
        if (item.type <= 0) {
            return newPosition;
        }
        vec2 centerPoint = vec2(item.point.x, item.point.y * useScreenRatio);
        vec2 ratioTransTargetPoint = vec2(newPosition.x, newPosition.y * useScreenRatio);
        float dist = distance(ratioTransTargetPoint, centerPoint);
        if (dist < item.radius) {
            float distRatio = dist / item.radius;
            float dx = centerPoint.x - ratioTransTargetPoint.x;
            float dy = (centerPoint.y - ratioTransTargetPoint.y) / useScreenRatio;
            if (item.type == 1) {
                float weight = 1.5 * (1.0 - sin(distRatio * 3.1415 * 0.5)) * item.strength;
                newPosition.x -= dx * weight;
                newPosition.y -= dy * weight;
            } else if (item.type == 2) {
                float weight = cos(3.1415 * 0.5 * distRatio) * item.strength;
                newPosition.x += dx * weight;
                newPosition.y += dy * weight;
            } else if (item.type == 3) {
                float weight = (cos(3.1415 * 0.5 * distRatio)) * item.radius * 0.5 / item.faceRatio * item.strength;
                vec2 vector = vec2(item.faceRatio, item.faceRatio / useScreenRatio);
                if (item.direction == 1) {
                    vector.x *= -weight; vector.y = 0.0;
                } else if (item.direction == 2) {
                    vector.x = 0.0; vector.y *= -weight;
                } else if (item.direction == 3) {
                    vector.x *= weight; vector.y = 0.0;
                } else if (item.direction == 4) {
                    vector.x = 0.0; vector.y *= weight;
                } else if (item.direction == 5) {
                    vector.x *= -weight; vector.y *= -weight;
                } else if (item.direction == 6) {
                    vector.x *= weight; vector.y *= -weight;
                } else if (item.direction == 7) {
                    vector.x *= -weight; vector.y *= weight;
                } else if (item.direction == 8) {
                    vector.x *= weight; vector.y *= weight;
                } else {
                    vector.x = 0.0; vector.y = 0.0;
                }
                newPosition.x += vector.x * cos(item.faceDegree) - vector.y * sin(item.faceDegree);
                newPosition.y += vector.y * cos(item.faceDegree) + vector.x * sin(item.faceDegree);
            }
        }
    }
    return newPosition;
}

void main() {
    textureCoordinate = inputTextureCoordinate.xy;
    gl_Position = distortedPosition(viewProjectionMatrix * position);
}
 
