//
//  GPUImageMeshFilter.m
//  faceCamera
//
//  Created by cain on 16/6/16.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "GPUImageMeshFilter.h"
#import <GLKit/GLKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


typedef struct BCVertex {
    GLKVector3 position;
    GLKVector3 normal;
    GLKVector2 uv;
} BCVertex;

NSString *const kImageMeshFString = SHADER_STRING
(
    varying highp vec2 textureCoordinate;
    uniform sampler2D inputImageTexture;
    void main() {
        lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
        gl_FragColor = textureColor;
    }
);


@implementation GPUImageMeshFilter

- (id)init;
{
    NSString *vertex = [[NSBundle mainBundle] pathForResource:@"mesh" ofType:@"vsh"];
    NSString *vertexString = [NSString stringWithContentsOfFile:vertex encoding:NSUTF8StringEncoding error:nil];
    if (!(self = [super initWithVertexShaderFromString:vertexString fragmentShaderFromString:kImageMeshFString]))
    {
        return nil;
    }
    
    _diffuseLightFactor = 1.0f;
    _lightDirection = BCPoint3DMake(0.0, 0.0, 1.0);
    
    _supplementaryTransform = CATransform3DIdentity;
    
    UIView *contentViewWrapperView = [UIView new];
    contentViewWrapperView.clipsToBounds = YES;
 
    [self setupGL];
    
    self.meshTransform = [MSMutableTransform identityMeshTransformWithNumberOfRows:((float)640. / (float)480) * 80. numberOfColumns:80];
    [self fillWithMeshTransform:self.meshTransform
                  positionScale:[self positionScaleWithDepthNormalization]];
    self.screenRatio = 5;
    return self;
}

-(void)setItems:(NSMutableArray *)items{
    for(int i=0;i<30;i++){
        if(i < [items count]){
            MeshItem *item = [items objectAtIndex:i];
            [self setInteger:item.type forUniformName:[[NSString alloc] initWithFormat:@"items[%d].type",i]];
            [self setInteger:item.direction forUniformName:[[NSString alloc] initWithFormat:@"items[%d].direction",i]];
            [self setFloat:item.strength forUniformName:[[NSString alloc] initWithFormat:@"items[%d].strength",i]];
            [self setFloat:item.radius forUniformName:[[NSString alloc] initWithFormat:@"items[%d].radius",i]];
            [self setFloat:item.faceDegree forUniformName:[[NSString alloc] initWithFormat:@"items[%d].faceDegree",i]];
            [self setFloat:item.faceRatio forUniformName:[[NSString alloc] initWithFormat:@"items[%d].faceRatio",i]];
            [self setPoint:item.point forUniformName:[[NSString alloc] initWithFormat:@"items[%d].point",i]];
        }else{
            [self setInteger:0 forUniformName:[[NSString alloc] initWithFormat:@"items[%d].type",i]];
        }
    }
}

-(void)setScreenRatio:(CGFloat)screenRatio{
    [self setFloat:screenRatio forUniformName:@"screenRatio"];
}

- (void)initializeAttributes;
{
    [filterProgram addAttribute:@"position"];
    [filterProgram addAttribute:@"normal"];
    [filterProgram addAttribute:@"inputTextureCoordinate"];
}

- (void)setupGL
{
    [[GPUImageContext sharedImageProcessingContext] useAsCurrentContext];
    
    glGenVertexArraysOES(1, &_VAO);
    glGenBuffers(1, &_indexBuffer);
    glGenBuffers(1, &_vertexBuffer);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{

    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    GLint viewProjectionMatrixUniform = [filterProgram uniformIndex:@"viewProjectionMatrix"];
    
    GLKMatrix4 viewProjectionMatrix = [self transformMatrix];
    glUniformMatrix4fv(viewProjectionMatrixUniform, 1, 0, viewProjectionMatrix.m);
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    glBindVertexArrayOES(self.VAO);
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(filterInputTextureUniform, 2);
 
    glDrawElements(GL_TRIANGLES, self.indiciesCount, GL_UNSIGNED_INT, 0);
    [firstInputFramebuffer unlock];
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(0);
    glBindVertexArrayOES(0);
}

#pragma mark - Geometry
- (GLKMatrix4)transformMatrix
{
    GLKMatrix4 matrix = GLKMatrix4Identity;
    matrix = GLKMatrix4Multiply(GLKMatrix4MakeTranslation(-0.5f, -0.5f, 0.0f), matrix);
    matrix = GLKMatrix4Multiply(GLKMatrix4MakeScale(2, 2, 0), matrix);
    matrix = GLKMatrix4Multiply(GLKMatrix4MakeRotation(M_PI, 1, 0,0), matrix);
    return matrix;
}

- (GLKVector3)positionScaleWithDepthNormalization
{
    float xScale = 640;
    float yScale = 480;
    float zScale = 0.5 * (xScale + yScale);
    return GLKVector3Make(xScale, yScale, zScale);
}


- (float)zScaleForDepthNormalization:(NSString *)depthNormalization
{
    static NSDictionary *dictionary;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dictionary = @{
                       kBCDepthNormalizationWidth   : ^float(CGSize size) { return size.width; },
                       kBCDepthNormalizationHeight  : ^float(CGSize size) { return size.height; },
                       kBCDepthNormalizationMin     : ^float(CGSize size) { return MIN(size.width, size.height); },
                       kBCDepthNormalizationMax     : ^float(CGSize size) { return MAX(size.width, size.height); },
                       kBCDepthNormalizationAverage : ^float(CGSize size) { return 0.5 * (size.width + size.height); },
                       };
    });

    return 0.0;
}

- (void)rebindVAO
{
    glBindVertexArrayOES(_VAO);
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glEnableVertexAttribArray([filterProgram attributeIndex:@"position"]);
    glVertexAttribPointer([filterProgram attributeIndex:@"position"], 3, GL_FLOAT, GL_FALSE, sizeof(BCVertex), (void *)offsetof(BCVertex, position));
    glEnableVertexAttribArray([filterProgram attributeIndex:@"inputTextureCoordinate"]);
    glVertexAttribPointer([filterProgram attributeIndex:@"inputTextureCoordinate"], 2, GL_FLOAT, GL_FALSE, sizeof(BCVertex), (void *)offsetof(BCVertex, uv));
    
    glBindVertexArrayOES(0);
}

#pragma mark - Buffers Filling
- (void)fillWithMeshTransform:(MSTransform *)transform
                positionScale:(GLKVector3)positionScale
{
    const int IndexesPerFace = 6;
    
    NSUInteger faceCount = transform.faceCount;
    NSUInteger vertexCount = transform.vertexCount;
    NSUInteger indexCount = faceCount * IndexesPerFace;
    
    [self resizeBuffersToVertexCount:vertexCount indexCount:indexCount];
    
    [self fillBuffersWithBlock:^(BCVertex *vertexData, GLuint *indexData) {
        for (int i = 0; i < vertexCount; i++) {
            BCMeshVertex meshVertex = [transform vertexAtIndex:i];
            CGPoint uv = meshVertex.from;
            
            BCVertex vertex;
            vertex.position = GLKVector3Make(meshVertex.to.x, meshVertex.to.y, meshVertex.to.z);
            vertex.uv = GLKVector2Make(uv.x, 1.0 - uv.y);
            vertex.normal = GLKVector3Make(0.0f, 0.0f, 0.0f);
            vertexData[i] = vertex;
        }
        
        for (int i = 0; i < faceCount; i++) {
            BCMeshFace face = [transform faceAtIndex:i];
            GLKVector3 weightedFaceNormal = GLKVector3Make(0.0f, 0.0f, 0.0f);
            
            // CAMeshTransform seems to be using the following order
            const int Winding[2][3] = {
                {0, 1, 2},
                {2, 3, 0}
            };
            
            GLKVector3 vertices[4];
            
            for (int j = 0; j < 4; j++) {
                unsigned int faceIndex = face.indices[j];
                if (faceIndex >= vertexCount) {
                    NSLog(@"Vertex index %u in face %d is out of bounds!", faceIndex, i);
                    return;
                }
                vertices[j] = GLKVector3Multiply(vertexData[faceIndex].position, positionScale);
            }
            
            for (int triangle = 0; triangle < 2; triangle++) {
                
                int aIndex = face.indices[Winding[triangle][0]];
                int bIndex = face.indices[Winding[triangle][1]];
                int cIndex = face.indices[Winding[triangle][2]];
                
                indexData[IndexesPerFace * i + triangle * 3 + 0] = aIndex;
                indexData[IndexesPerFace * i + triangle * 3 + 1] = bIndex;
                indexData[IndexesPerFace * i + triangle * 3 + 2] = cIndex;
                
                GLKVector3 a = vertices[Winding[triangle][0]];
                GLKVector3 b = vertices[Winding[triangle][1]];
                GLKVector3 c = vertices[Winding[triangle][2]];
                
                GLKVector3 ab = GLKVector3Subtract(a, b);
                GLKVector3 cb = GLKVector3Subtract(c, b);
                
                GLKVector3 weightedNormal = GLKVector3CrossProduct(ab, cb);
                
                weightedFaceNormal = GLKVector3Add(weightedFaceNormal, weightedNormal);
            }

            for (int i = 0; i < 4; i++) {
                int vertexIndex = face.indices[i];
                vertexData[vertexIndex].normal = GLKVector3Add(vertexData[vertexIndex].normal, weightedFaceNormal);
            }
        }
        
        for (int i = 0; i < vertexCount; i++) {
            
            GLKVector3 normal = vertexData[i].normal;
            float length = GLKVector3Length(normal);
            
            if (length > 0.0) {
                vertexData[i].normal = GLKVector3MultiplyScalar(normal, 1.0/length);
            }
        }
    }];
    
    
    _indiciesCount = (GLsizei)indexCount;
}

- (void)fillBuffersWithBlock:(void (^)(BCVertex *vertexData, GLuint *indexData))block
{
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    BCVertex *vertexData = glMapBufferOES(GL_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    GLuint *indexData = glMapBufferOES(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
    block(vertexData, indexData);
    glUnmapBufferOES(GL_ELEMENT_ARRAY_BUFFER);
    glUnmapBufferOES(GL_ARRAY_BUFFER);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

#pragma mark - Resizing

static inline GLsizeiptr nextPoTForSize(NSUInteger size)
{
    // using a builtin to Count Leading Zeros
    unsigned int bitCount = sizeof(unsigned int) * CHAR_BIT;
    unsigned int log2 = bitCount - __builtin_clz((unsigned int)size);
    GLsizeiptr nextPoT = 1u << log2;
    
    return nextPoT;
}

- (void)resizeBuffersToVertexCount:(NSUInteger)vertexCount indexCount:(NSUInteger)indexCount
{
    BOOL rebindVAO = NO;
    
    if (_vertexBufferCapacity < vertexCount) {
        _vertexBufferCapacity = nextPoTForSize(vertexCount);
        [self resizeVertexBufferToCapacity:_vertexBufferCapacity];
        rebindVAO = YES;
    }
    
    if (_indexBufferCapacity < indexCount) {
        _indexBufferCapacity = nextPoTForSize(indexCount);
        [self resizeIndexBufferToCapacity:_indexBufferCapacity];
        rebindVAO = YES;
    }
    
    if (rebindVAO) {
        [self rebindVAO];
    }
}


- (void)resizeVertexBufferToCapacity:(GLsizeiptr)capacity
{
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, capacity * sizeof(BCVertex), NULL, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void)resizeIndexBufferToCapacity:(GLsizeiptr)capacity
{
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, capacity * sizeof(GLuint), NULL, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void)dealloc
{
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArraysOES(1, &_VAO);
}


@end
