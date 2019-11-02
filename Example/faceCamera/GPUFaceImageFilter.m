//
//  GPUImageMeshFilter.m
//  faceCamera
//
//  Created by cain on 16/6/16.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "GPUFaceImageFilter.h"
#import <GLKit/GLKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


typedef struct BCVertex {
    GLKVector3 position;
    GLKVector3 normal;
    GLKVector2 uv;
} BCVertex;

NSString *const kImageFaceString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform highp float faceCount;

 void main() {
     if(faceCount > 0.){
         lowp vec4 c2 = texture2D(inputImageTexture, textureCoordinate);
         gl_FragColor = c2;
         return;
     }
     gl_FragColor = vec4(0.0);
 }
 );

NSString *const kImageFaceVString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     gl_PointSize = 5.0;
 }
);

@interface GPUFaceImageFilter()

@property NSMutableArray *allUV;
@property NSArray *allVertex;
@property NSArray *allIndex;
@property BOOL needUp;

@end

@implementation GPUFaceImageFilter

- (id)init;
{
    if (!(self = [super initWithVertexShaderFromString:kImageFaceVString fragmentShaderFromString:kImageFaceString]))
    {
        return nil;
    }
    
    self.allVertex = @[
                        @"{ -0.6648148,0.3320236,0}",
                        @"{ -0.6611112,0.2298624,0}",
                        @"{ -0.6537038,0.1414538,0}",
                        @"{ -0.6444444,0.058939,0}",
                        @"{ -0.6351852,-0.0196464,0}",
                        @"{ -0.624074,-0.092338,0}",
                        @"{ -0.6,-0.1925344,0}",
                        @"{ -0.5666666,-0.2946954,0}",
                        @"{ -0.5388888,-0.394892,0}",
                        @"{ -0.5,-0.4872298,0}",
                        @"{ -0.45,-0.5736738,0}",
                        @"{ -0.3907408,-0.6561886,0}", //12
                        @"{ -0.3277778,-0.7229862,0}",
                        @"{ -0.2648148,-0.7819254,0}",
                        @"{ -0.1962962,-0.8349706,0}",
                        @"{ -0.0925926,-0.8742632,0}",
                        @"{ 0,-0.8840864,0}",
                        @"{ 0.0925926,-0.8781926,0}",
                        @"{ 0.1944444,-0.8369352,0}",
                        @"{ 0.2648148,-0.7819254,0}",
                        @"{ 0.3277778,-0.7249508,0}",
                        @"{ 0.3925926,-0.654224,0}",
                        @"{ 0.45,-0.5736738,0}",
                        @"{ 0.5,-0.4872298,0}",
                        @"{ 0.5388888,-0.394892,0}", //24
                        @"{ 0.5685186,-0.2946954,0}",
                        @"{ 0.6018518,-0.1886052,0}",
                        @"{ 0.625926,-0.0943026,0}",
                        @"{ 0.637037,-0.0196464,0}",
                        @"{ 0.6462962,0.058939,0}",
                        @"{ 0.6537038,0.1453832,0}",
                        @"{ 0.6611112,0.2318272,0}",
                        @"{ 0.662963,0.3320236,0}", //外部轮廓 32 16*2
                        @"{ -0.5703704,0.35167,0}",
                        @"{ -0.4851852,0.4282908,0}",
                        @"{ -0.35,0.4341846,0}",
                        @"{ -0.2314814,0.4145384,0}",
                        @"{ -0.1333334,0.3752456,0}",//左眼眉毛之间
                        @"{ 0.1314814,0.3772102,0}",
                        @"{ 0.2296296,0.4145384,0}",
                        @"{ 0.3518518,0.43222,0}",
                        @"{ 0.4833334,0.4263262,0}",
                        @"{ 0.5722222,0.35167,0}",  //右眼眉毛之间
                        @"{ 0,0.237721,0}",
                        @"{ 0.0018518000000001,0.0785854,0}",
                        @"{ 0.0018518000000001,-0.0785854,0}",
                        @"{ 0,-0.1964636,0}",   //中心线 有值
                        @"{ -0.1166666,-0.2671906,0}",
                        @"{ -0.062963,-0.2829076,0}",
                        @"{ 0,-0.2966602,0}",
                        @"{ 0.0611112,-0.2829076,0}",
                        @"{ 0.1166666,-0.2671906,0}", //鼻子底部
                        @"{ -0.462963,0.1886052,0}",
                        @"{ -0.3685186,0.2475442,0}",
                        @"{ -0.2481482,0.2455796,0}",
                        @"{ -0.1611112,0.1532416,0}",
                        @"{ -0.25,0.13556,0}",
                        @"{ -0.3722222,0.13556,0}", //左眼 有值
                        @"{ 0.1592592,0.1532416,0}",
                        @"{ 0.2481482,0.2475442,0}",
                        @"{ 0.3685186,0.2475442,0}",
                        @"{ 0.462963,0.1886052,0}",
                        @"{ 0.3685186,0.13556,0}",
                        @"{ 0.2481482,0.13556,0}",//右眼 有值
                        @"{ -0.4888888,0.3654224,0}",
                        @"{ -0.362963,0.3614932,0}",
                        @"{ -0.2333334,0.3477406,0}",
                        @"{ -0.1444444,0.324165,0}", //左眉毛 有值
                        @"{ 0.1444444,0.3261296,0}",
                        @"{ 0.2333334,0.3438114,0}",
                        @"{ 0.362963,0.3614932,0}",
                        @"{ 0.4888888,0.3654224,0}", //右眉毛 有值
                        @"{ -0.3074074,0.2573674,0}",
                        @"{ -0.3055556,0.1237722,0}",
                        @"{ -0.3092592,0.1925344,0}", //左眼中心 没值
                        @"{ 0.3074074,0.259332,0}",
                        @"{ 0.3074074,0.1257368,0}",
                        @"{ 0.3074074,0.1905698,0}", //右眼中心  没值
                        @"{ -0.0962962,0.2121808,0}",
                        @"{ 0.0962962,0.2121808,0}", //鼻子根部左右
                        @"{ -0.1092592,-0.1277014,0}",
                        @"{ 0.1092592,-0.1277014,0}",
                        @"{ -0.1574074,-0.2357564,0}",
                        @"{ 0.1574074,-0.237721,0}", //鼻子中下部
                        @"{ -0.2555556,-0.4695482,0}",
                        @"{ -0.1592592,-0.4420432,0}",
                        @"{ -0.074074,-0.4223968,0}",
                        @"{ 0,-0.4499018,0}",
                        @"{ 0.074074,-0.4223968,0}",
                        @"{ 0.1592592,-0.4420432,0}",
                        @"{ 0.2555556,-0.4695482,0}",
                        @"{ 0.1592592,-0.546169,0}",
                        @"{ 0.0962962,-0.5874264,0}",
                        @"{ 0,-0.5992142,0}",
                        @"{ -0.0962962,-0.5854616,0}",
                        @"{ -0.1611112,-0.5442044,0}", //嘴巴外围  有值
                        @"{ -0.2222222,-0.4734774,0}",
                        @"{ -0.0962962,-0.4793714,0}",
                        @"{ 0,-0.4852652,0}",
                        @"{ 0.0962962,-0.4793714,0}",
                        @"{ 0.2222222,-0.4734774,0}",//嘴巴上侧  有值
                        @"{ 0.0703704,-0.4931238,0}",
                        @"{ 0,-0.497053,0}",
                        @"{ -0.0703704,-0.4931238,0}",//嘴巴下侧   有值
                        @"{ -0.3018518,0.1905698,0}",
                        @"{ 0.2981482,0.1925344,0}", //眼睛下侧两点
                        @"{ -0.4055556,-0.2730844,0}",
                        @"{ 0.4018518,-0.2750492,0}",//腮帮两侧
                        @"{ -0.5092592,0.6070726,0}",
                        @"{ -0.2537038,0.6070726,0}",
                        @"{ 0,0.6070726,0}",
                        @"{ 0.2537038,0.6070726,0}",
                        @"{ 0.5092592,0.6070726,0}", //脸部上侧
                        @"{ -1,0.9960708,0}",
                        @"{ 0.3055556,1.0,0}",
                        @"{ 0.9907408,0.9921414,0}",
                        @"{ -1,0.0,0}",
                        @"{ 0.9907408,0.0844794,0}",
                        @"{ -1,-0.9921414,0}",
                        @"{ 0.0055556000000001,-0.9921414,0}",
                        @"{ 0.9907408,-0.9921414,0}",
                      ];
 
    [self setupGL];
    self.items = nil;
    self.needUp = YES;
    return self;
}

- (void)setupGL
{
    [[GPUImageContext sharedImageProcessingContext] useAsCurrentContext];
    glGenVertexArraysOES(1, &_VAO);
    glGenBuffers(1, &_indexBuffer);
    glGenBuffers(1, &_vertexBuffer);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

}

-(void)resetEmptyVertex{
    NSUInteger indexCount = 6;
    NSUInteger vertexCount = 4;
    [self resizeBuffersToVertexCount:vertexCount indexCount:indexCount];
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    BCVertex *vertexData = glMapBufferOES(GL_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    GLuint *indexData = glMapBufferOES(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
    BCVertex vData[] = {
        {{1.,-1.,0.},{1.,0.,0.},{1.,0.}},
        {{1.,1.,0.},{0.,1.,0.},{1.,1.}},
        {{-1.,1.,0.},{0.,0.,1.},{0.,1.}},
        {{-1.,-1.,0.},{0.,0.,0.},{0.,0.}}
    };
    memcpy(vertexData, &vData, sizeof(vData));
    GLuint iData[] =  {
        0,1,2,
        2,3,0
    };
    memcpy(indexData, &iData, sizeof(iData));
    
    glUnmapBufferOES(GL_ARRAY_BUFFER);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glUnmapBufferOES(GL_ELEMENT_ARRAY_BUFFER);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    _indiciesCount = (GLsizei)indexCount;
}

-(void)resetVertex:(NSArray *)item{
    NSUInteger indexCount = 6;
    NSUInteger vertexCount = 4;
 
    indexCount = self.allIndex.count;
    vertexCount = self.allVertex.count;

    [self resizeBuffersToVertexCount:vertexCount indexCount:indexCount];
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    BCVertex *vertexData = glMapBufferOES(GL_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
 
    for (int i = 0; i < vertexCount; i++) {
        BCVertex vertex;
        CGPoint verter = [[item objectAtIndex:i] CGPointValue];
        CGPoint uv = [[self.allUV objectAtIndex:i] CGPointValue];
        vertex.position = GLKVector3Make(verter.x, verter.y, 0);
        vertex.uv = GLKVector2Make(uv.x,uv.y);
        vertex.normal = GLKVector3Make(0.0f, 0.0f, 0.0f);
        vertexData[i] = vertex;
    }
    
    if(self.needUp){
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        GLuint *indexData = glMapBufferOES(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
        for (int i = 0; i < indexCount; i++) {
            indexData[i] = [[self.allIndex objectAtIndex:i] intValue];
        }
        glUnmapBufferOES(GL_ELEMENT_ARRAY_BUFFER);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }

    glUnmapBufferOES(GL_ARRAY_BUFFER);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    _indiciesCount = (GLsizei)indexCount;
}

-(void)setItems:(NSMutableArray *)items{
    _items = items;
    [self setFloat:items.count forUniformName:@"faceCount"];
}

-(void)updateWith:(NSString *)crdFile :(NSString *)idxFile{
    NSString* content;
    if([[NSFileManager defaultManager] fileExistsAtPath:idxFile]){
        content = [NSString stringWithContentsOfFile:idxFile
                                                      encoding:NSUTF8StringEncoding
                                                         error:NULL];
        [content stringByReplacingOccurrencesOfString:@" " withString:@""];
        content = [Utils trim:[content stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
        self.allIndex = [content componentsSeparatedByString: @","];
    }else{
    self.allIndex = @[@"33",@"34",@"64",@"34",@"35",@"64",@"35",@"64",@"65",@"35",@"36",@"65",@"36",@"65",@"66",@"36",@"37",@"66",@"37",@"67",@"66",@"38",@"39",@"68",@"39",@"69",@"68",@"39",@"40",@"69",@"40",@"70",@"69",@"40",@"41",@"70",@"41",@"71",@"70",@"41",@"42",@"71",@"52",@"53",@"74",@"53",@"72",@"74",@"72",@"54",@"74",@"54",@"55",@"74",@"55",@"56",@"74",@"56",@"73",@"74",@"73",@"57",@"74",@"57",@"52",@"74",@"58",@"59",@"77",@"59",@"75",@"77",@"75",@"60",@"77",@"60",@"61",@"77",@"61",@"62",@"77",@"62",@"76",@"77",@"76",@"63",@"77",@"63",@"58",@"77",@"82",@"47",@"46",@"47",@"48",@"46",@"48",@"49",@"46",@"49",@"50",@"46",@"50",@"51",@"46",@"51",@"83",@"46",@"82",@"80",@"46",@"80",@"45",@"46",@"45",@"81",@"46",@"81",@"83",@"46",@"80",@"44",@"45",@"78",@"44",@"80",@"44",@"45",@"81",@"79",@"44",@"81",@"78",@"43",@"44",@"43",@"79",@"44",@"84",@"85",@"96",@"85",@"86",@"96",@"86",@"97",@"96",@"86",@"87",@"97",@"87",@"98",@"97",@"87",@"88",@"98",@"88",@"99",@"98",@"88",@"89",@"99",@"89",@"100",@"99",@"89",@"90",@"100",@"84",@"103",@"95",@"103",@"94",@"95",@"103",@"102",@"94",@"102",@"93",@"94",@"102",@"101",@"93",@"101",@"92",@"93",@"101",@"91",@"92",@"101",@"90",@"91",@"0",@"33",@"108",@"33",@"34",@"108",@"108",@"34",@"109",@"34",@"35",@"109",@"35",@"36",@"109",@"109",@"110",@"36",@"36",@"37",@"110",@"37",@"38",@"110",@"38",@"39",@"110",@"110",@"39",@"111",@"39",@"40",@"111",@"40",@"41",@"111",@"111",@"41",@"112",@"41",@"42",@"112",@"42",@"32",@"112",@"0",@"33",@"52",@"0",@"1",@"52",@"1",@"2",@"52",@"52",@"106",@"2",@"2",@"3",@"106",@"3",@"4",@"106",@"52",@"57",@"106",@"4",@"5",@"106",@"5",@"6",@"106",@"6",@"7",@"106",@"7",@"8",@"84",@"8",@"9",@"84",@"84",@"95",@"9",@"9",@"10",@"95",@"10",@"11",@"95",@"11",@"12",@"95",@"12",@"13",@"95",@"95",@"94",@"13",@"13",@"14",@"94",@"94",@"93",@"14",@"93",@"15",@"14",@"93",@"16",@"15",@"93",@"16",@"17",@"93",@"92",@"17",@"92",@"91",@"17",@"91",@"18",@"17",@"91",@"19",@"18",@"91",@"20",@"19",@"91",@"90",@"20",@"90",@"21",@"20",@"90",@"22",@"21",@"90",@"23",@"22",@"90",@"24",@"23",@"90",@"25",@"24",@"25",@"107",@"26",@"107",@"27",@"26",@"107",@"28",@"27",@"107",@"29",@"28",@"107",@"30",@"29",@"61",@"107",@"30",@"61",@"31",@"30",@"32",@"31",@"61",@"32",@"42",@"61",@"33",@"64",@"52",@"64",@"53",@"52",@"64",@"65",@"53",@"65",@"66",@"53",@"66",@"72",@"53",@"66",@"54",@"72",@"66",@"67",@"54",@"67",@"55",@"54",@"37",@"38",@"67",@"67",@"38",@"68",@"67",@"78",@"55",@"67",@"43",@"78",@"67",@"68",@"43",@"43",@"79",@"68",@"79",@"58",@"81",@"79",@"58",@"68",@"58",@"59",@"68",@"68",@"69",@"59",@"59",@"75",@"69",@"69",@"70",@"75",@"75",@"60",@"70",@"70",@"71",@"60",@"71",@"42",@"61",@"71",@"61",@"60",@"61",@"62",@"107",@"76",@"62",@"107",@"76",@"63",@"83",@"58",@"63",@"81",@"63",@"81",@"83",@"57",@"73",@"106",@"55",@"78",@"80",@"56",@"55",@"80",@"56",@"80",@"82",@"56",@"73",@"82",@"73",@"106",@"82",@"76",@"83",@"107",@"106",@"7",@"84",@"106",@"82",@"84",@"84",@"82",@"85",@"82",@"47",@"85",@"107",@"25",@"90",@"107",@"90",@"83",@"47",@"48",@"85",@"48",@"85",@"86",@"48",@"49",@"86",@"49",@"86",@"87",@"49",@"87",@"88",@"49",@"50",@"88",@"50",@"51",@"88",@"51",@"89",@"88",@"51",@"83",@"89",@"83",@"89",@"90"];
    }

    if(![[NSFileManager defaultManager] fileExistsAtPath:crdFile]){
        return;
    }
    content = [NSString stringWithContentsOfFile:crdFile
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    content = [Utils trim:[content stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
    NSArray *crdItems = [content componentsSeparatedByString: @","];
    self.allUV = [NSMutableArray new];
    for (int i=0; i < (crdItems.count - 1); i += 2) {
        [self.allUV addObject:[NSValue valueWithCGPoint:CGPointMake([crdItems[i] floatValue],[crdItems[i+1] floatValue])]];
    }
    self.needUp = YES;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        [secondInputFramebuffer unlock];
        return;
    }
    [GPUImageContext setActiveShaderProgram:filterProgram];
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }

    [self setUniformsForProgramAtIndex:0];
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if(self.items){
        int i = 0;
        for (NSArray *item in self.items) {
            [self resetVertex:item];
            glBindVertexArrayOES(self.VAO);
            glActiveTexture(GL_TEXTURE2);
            glBindTexture(GL_TEXTURE_2D, [secondInputFramebuffer texture]);
//            glActiveTexture(GL_TEXTURE3);
//            glBindTexture(GL_TEXTURE_2D, [secondInputFramebuffer texture]);
            glUniform1i(filterInputTextureUniform, 2);
//            glUniform1i(filterInputTextureUniform2, 3);
            glDrawElements(GL_TRIANGLES, self.indiciesCount, GL_UNSIGNED_INT, 0);
            glBindVertexArrayOES(0);
            i++;
        }
    }else{
        [self resetEmptyVertex];
        glBindVertexArrayOES(self.VAO);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, [secondInputFramebuffer texture]);
        glUniform1i(filterInputTextureUniform, 2);
        glDrawElements(GL_TRIANGLES, self.indiciesCount, GL_UNSIGNED_INT, 0);
    }
    
    [firstInputFramebuffer unlock];
    [secondInputFramebuffer unlock];
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
 
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(0);
    glBindVertexArrayOES(0);
}

#pragma mark - Geometry

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
