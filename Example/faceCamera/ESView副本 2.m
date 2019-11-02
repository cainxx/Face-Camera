
#import "ESView.h"
#import <GLKit/GLKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreGraphics/CGAffineTransform.h>
#import "GLTexture.h"
#import "FGLKProgram.h"
#import "ParticleEmitter.h"
#import "GLMath.h"
#import "CLImageToolInfo.h"
#import "WDPaintingFragment.h"
//#import "PPSSignatureView.h"

#define DEGREES_TO_RADIANS(degrees)((M_PI * degrees)/180)
#define WDCheckGLError() WDCheckGLError_(__FILE__, __LINE__);
#define LOG_EXPR(_X_) do{\
__typeof__(_X_) _Y_ = (_X_);\
const char * _TYPE_CODE_ = @encode(__typeof__(_X_));\
NSString *_STR_ = VTPG_DDToStringFromTypeAndValue(_TYPE_CODE_, &_Y_);\
if(_STR_)\
NSLog(@"%s = %@", #_X_, _STR_);\
else\
NSLog(@"Unknown _TYPE_CODE_: %s for expression %s in function %s, file %s, line %d", _TYPE_CODE_, #_X_, __func__, __FILE__, __LINE__);\
}while(0)

#define kBrushOpacity		(1.0 / 3.0)
#define kBrushPixelStep		3
#define kBrushScale			2


//////
#define             STROKE_WIDTH_MIN 0.004 // Stroke width determined by touch velocity
#define             STROKE_WIDTH_MAX 0.030
#define       STROKE_WIDTH_SMOOTHING 0.9   // Low pass filter alpha

#define           VELOCITY_CLAMP_MIN 20
#define           VELOCITY_CLAMP_MAX 5000

#define QUADRATIC_DISTANCE_TOLERANCE 1.0   // Minimum distance to make a curve

#define             MAXIMUM_VERTECES 100000


static GLKVector3 StrokeColor = { 0, 0, 0 };

// Vertex structure containing 3D point and color
struct PPSSignaturePoint
{
    GLKVector3		vertex;
    GLKVector3		color;
};
typedef struct PPSSignaturePoint PPSSignaturePoint;


// Maximum verteces in signature
static const int maxLength = MAXIMUM_VERTECES;


// Append vertex to array buffer
static inline void addVertex(uint *length, PPSSignaturePoint v) {
    //    NSLog(@"length %d",*length);
    if ((*length) >= maxLength) {
        return;
    }
    
    GLvoid *data = glMapBufferOES(GL_ARRAY_BUFFER, GL_WRITE_ONLY_OES);
    memcpy(data + sizeof(PPSSignaturePoint) * (*length), &v, sizeof(PPSSignaturePoint));
    glUnmapBufferOES(GL_ARRAY_BUFFER);
    
    (*length)++;
}

static inline CGPoint QuadraticPointInCurve(CGPoint start, CGPoint end, CGPoint controlPoint, float percent) {
    double a = pow((1.0 - percent), 2.0);
    double b = 2.0 * percent * (1.0 - percent);
    double c = pow(percent, 2.0);
    
    return (CGPoint) {
        a * start.x + b * controlPoint.x + c * end.x,
        a * start.y + b * controlPoint.y + c * end.y
    };
}

static float clamp(float min, float max, float value) { return fmaxf(min, fminf(max, value)); }


// Find perpendicular vector from two other vectors to compute triangle strip around line
static GLKVector3 perpendicular(PPSSignaturePoint p1, PPSSignaturePoint p2) {
    GLKVector3 ret;
    ret.x = p2.vertex.y - p1.vertex.y;
    ret.y = -1 * (p2.vertex.x - p1.vertex.x);
    ret.z = 0;
    return ret;
}

static PPSSignaturePoint ViewPointToGL(CGPoint viewPoint, CGRect bounds, GLKVector3 color) {
    return (PPSSignaturePoint) {
        {
            (viewPoint.x / bounds.size.width * 2.0 - 1),
            ((viewPoint.y / bounds.size.height) * 2.0 - 1) * -1,
            0
        },
        color
    };
}


///////


void WDCheckGLError_(const char* file, int line) {
    GLenum error = glGetError();
    if (error) {
        NSString *message;
        switch (error) {
            case GL_INVALID_ENUM: message = @"invalid enum"; break;
            case GL_INVALID_FRAMEBUFFER_OPERATION: message = @"invalid framebuffer operation"; break;
            case GL_INVALID_OPERATION: message = @"invalid operation"; break;
            case GL_INVALID_VALUE: message = @"invalid value"; break;
            case GL_OUT_OF_MEMORY: message = @"out of memory"; break;
            default: message = [NSString stringWithFormat:@"unknown error: 0x%x", error];
        }
        NSLog(@"ERROR: glGetError returned: %@ at %s:%d", message, file, line);
    }
}

typedef enum{
    SPIRIT,
    ANIMATION
}TIMERTYPE;

enum {
    ATTRIB_VERTEX,
    NUM_ATTRIBS
};
enum {
    PROGRAM_POINT,
    NUM_PROGRAMS
};

enum {
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};

typedef struct {
    char *vert, *frag;
    GLint uniform[NUM_UNIFORMS];
    GLuint id;
} programInfo_t;

typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2];
} Vertex;

typedef struct TextureVector4{
    GLKVector2 bl;
    GLKVector2 br;
    GLKVector2 tl;
    GLKVector2 tr;
} TextureVector4;

typedef struct TranVertex{
    CGRect rect;
    CGPoint point[4];
} TranVertex;

programInfo_t program[NUM_PROGRAMS] = {
    { "point.vsh",   "point.fsh" },     // PROGRAM_POINT
};

@interface ESView(){
    //   textureVector4 textureVectorArray[10];
    UIBezierPath *path;
    
    GLuint vertexArray;
    GLuint PPSVertexBuffer;
    GLuint dotsArray;
    GLuint dotsBuffer;
    
    // Array of verteces, with current length
    PPSSignaturePoint SignatureVertexData[maxLength];
    uint length;
    
    PPSSignaturePoint SignatureDotsData[maxLength];
    uint dotsLength;
    
    // Width of line at current and previous vertex
    float penThickness;
    float previousThickness;
    
    // Previous points for quadratic bezier computations
    CGPoint previousPoint;
    CGPoint previousMidPoint;
    PPSSignaturePoint previousVertex;
    PPSSignaturePoint currentVelocity;
}

@property (strong, nonatomic) CAEAGLLayer * eaglLayer;
@property (assign, nonatomic) GLuint renderBuffer;
@property (assign, nonatomic) GLuint frameBuffer;
//@property (assign, nonatomic) GLuint frameBuffer2;
@property (assign, nonatomic) GLuint reusableFramebuffer;
@property (assign, nonatomic) GLuint stencilBuffer;

@property (assign, nonatomic) GLuint positionSlot;
@property (assign, nonatomic) GLuint colorSlot;
@property (assign, nonatomic) GLuint progarmHandle;
@property (assign, nonatomic) GLuint bgtexture;
@property (nonatomic) GLTexture *sourceTexture;
@property (nonatomic) GLTexture *backBufferTexture;
@property (assign, nonatomic) GLuint texCoordSlot;
@property (assign, nonatomic) GLuint textureUniform;

@property (strong, nonatomic) GLKBaseEffect     *effect;
@property (strong, nonatomic) ParticleEmitter   *pe;
@property (strong, nonatomic) GLKBaseEffect     *particleEmitterEffect;
@property (strong, nonatomic) NSMutableArray    *particleEmitters;
@property (strong, nonatomic) NSEnumerator      *particleEnumerator;
@property NSTimeInterval timeSinceLastUpdate;
@property NSTimeInterval timeBegin;
@property CADisplayLink *displayLink;
@property NSInteger curPe;
@property CGFloat bgImgHUseRatio;
@property CGFloat bgImgWUseRatio;
@property CGFloat screenScale;
@property CGPoint endPoint;
@property NSMutableArray *textureVector;
@property CGFloat subTextureWRatio;
@property CGFloat subTextureHRatio;
@property CGFloat subTextureHWRatio;

@property NSMutableDictionary *curBrush;
@property CLImageToolInfo *curToolInfo;
@property NSMutableDictionary *brushConfig;

@property (nonatomic) FGLKProgram *program;
@property BOOL beginAnimatio;
@property BOOL beginSpirit;
@property (nonatomic, strong) NSUndoManager *undoManager;

@property CGRect BGRect;
@property NSData *fragmentData;
@property BOOL changed;

@property UIImageView *tempImgView;
@property unsigned char *rawData;
@property NSMutableDictionary *programsCache;
@property CGRect lastDrawRect;

@property BOOL inited;
@property GLTexture *brushTextue;

@end

const Vertex Vertices3[] = {
    {{-1,1,0},{0,0,0,1},{0,0}},
    {{1,1,0},{0,0,0,1},{1,0}},
    {{-1,-1,0},{0,0,1,1},{0,1}},
    {{1,-1,0},{0,0,0,1},{1,1}}
};

const GLubyte Indices[] = {
    0,1,2,
    2,3,0
};

@implementation ESView

@synthesize  location;
@synthesize  previousLocation;
@synthesize  undoManager;

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
    }
    return self;
}

+(Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)layoutSubviews {
    //    self.mainImage = [UIImage imageNamed:@"IMG_0238_2.JPG"];
    //    self.mainImage = [self.mainImage aspectFit:CGSizeMake(2048, 2048)];
    if(self.inited){
        return;
    }
    self.backgroundColor = [UIColor redColor];
    self.inited = YES;
    self.undoManager = [[NSUndoManager alloc] init];
    self.screenScale = self.contentScaleFactor;
    self.programsCache = [NSMutableDictionary new];
    
    [self setup];
    [self renderBG];
    [self display];
//    [self setupTexture];
//    [self upFragmentData];
    
//    self.tempImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
//    [self addSubview:self.tempImgView];
//    CGImageRef imageRef = self.mainImage.CGImage;
//    NSUInteger width = CGImageGetWidth(imageRef);
//    NSUInteger height = CGImageGetHeight(imageRef);
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    self.rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
//    NSUInteger bytesPerPixel = 4;
//    NSUInteger bytesPerRow = bytesPerPixel * width;
//    NSUInteger bitsPerComponent = 8;
//    CGContextRef context = CGBitmapContextCreate(self.rawData, width, height,
//                                                 bitsPerComponent, bytesPerRow, colorSpace,
//                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
//    CGColorSpaceRelease(colorSpace);
//    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
//    CGContextRelease(context);
  //  CGImageRelease(imageRef);
    self.brushColor = [UIColor colorWithRGBHex:0xa5825c];
    
}

- (void)setup {
    _eaglLayer = (CAEAGLLayer *)self.layer;
    _eaglLayer.opaque = YES;
    //    _eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking:@NO,kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8};
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    NSAssert([EAGLContext setCurrentContext:_context], @"set context failed");
    
    //    glGenFramebuffers(1, &_reusableFramebuffer);
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
//    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER,4,GL_RGBA8_OES,self.width * 2,self.height * 2);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    // also need a stencil buffer
    //    glGenRenderbuffers(1, &_stencilBuffer);
    
    glGenVertexArraysOES(1, &vertexArray);
    glGenBuffers(1, &PPSVertexBuffer);
    glGenVertexArraysOES(1, &dotsArray);
    
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    UIColor *backgroundColor = AppDelegate.theme.backgroundColor;
    glClearColor(backgroundColor.red, backgroundColor.green, backgroundColor.blue, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glViewport(0, 0, backingWidth, backingHeight);
    
    //    glEnable(GL_MULTISAMPLE);
    
    self.backBufferTexture = [GLTexture textureWithImage:self.mainImage];
    CGFloat HWScale = self.mainImage.size.height / self.mainImage.size.width;
    CGFloat screenScale = (CGFloat)backingWidth / (CGFloat)backingHeight;
    if((backingWidth)/self.mainImage.size.width > backingHeight / self.mainImage.size.height){
        self.bgImgHUseRatio = 1.0;
        self.bgImgWUseRatio = self.mainImage.size.width / self.mainImage.size.height * ((CGFloat)backingHeight / (CGFloat)backingWidth);
    }else{
        self.bgImgWUseRatio = 1.0;
        self.bgImgHUseRatio = HWScale * screenScale;
    }
    
    float y = floor((float)backingHeight * ((1. - self.bgImgHUseRatio)/2.));
    self.BGRect = CGRectMake(floor((float)backingWidth * ((1. - self.bgImgWUseRatio)/2.)) , y , floor(backingWidth * self.bgImgWUseRatio) , floor(backingHeight * self.bgImgHUseRatio));
    
//    NSLog(@"self.BGRect %f %f %@",(float)backingWidth,(float)backingHeight,NSStringFromCGRect( self.BGRect));
    
    self.effect = [[GLKBaseEffect alloc] init];
    GLKMatrix4 ortho = GLKMatrix4MakeOrtho(-1, 1, -1, 1, 0.1f, 2.0f);
    self.effect.transform.projectionMatrix = ortho;
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.0f);
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    
    length = 0;
    penThickness = 0.003;
    previousPoint = CGPointMake(-100, -100);
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    pan.maximumNumberOfTouches = pan.minimumNumberOfTouches = 1;
    pan.cancelsTouchesInView = YES;
    [self addGestureRecognizer:pan];
}

-(FGLKProgram *)genProgram:(NSString *)v :(NSString *)f{
    NSString *key = [[NSString alloc] initWithFormat:@"%@-%@",v,f];
    if([self.programsCache objectForKey:key]){
        return [self.programsCache objectForKey:key];
    }
    
    FGLKProgram *program = [[FGLKProgram alloc] initWithVertexShaderName:v fragmentShaderName:f];
    [program bindAttributes:@{@(0):@"inPosition",@(1):@"inColor",@(2):@"inTexcoord"}];
    [program link];
    [program use];
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    glUniformMatrix4fv([program uniformIndex:@"MVP"], 1, GL_FALSE, MVPMatrix.m);
    glUniform2f([program uniformIndex:@"backbufferSize"], backingWidth, backingHeight);
    //    glUniform2f([program uniformIndex:@"backbufferOffset"], 0.0, (1.0 - self.bgImgHUseRatio);
    [self.programsCache setValue:program forKey:key];
    
    return program;
}

-(void)bindBuffer:(Vertex[])vertices{
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices3), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)(sizeof(float) * 3));
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)(sizeof(float) * 7));
}

- (void)renderBG {
    glClear(GL_COLOR_BUFFER_BIT);
    glBlendFunc(GL_ONE, GL_NONE);
    
    Vertex vertices[] = {
        {{self.bgImgWUseRatio - self.bgImgWUseRatio * 2.,self.bgImgHUseRatio,0},{0,0,0,1},{0,0}},
        {{self.bgImgWUseRatio,self.bgImgHUseRatio,0},{0,0,0,1},{1,0}},
        {{self.bgImgWUseRatio - self.bgImgWUseRatio * 2,self.bgImgHUseRatio - self.bgImgHUseRatio * 2.,0},{0,0,1,1},{0,1}},
        {{self.bgImgWUseRatio,self.bgImgHUseRatio - self.bgImgHUseRatio * 2.,0},{0,0,0,1},{1,1}}
    };
    FGLKProgram *sprogram = [self genProgram:@"blit" :@"blit"];
    [sprogram use];
    [self bindBuffer:vertices];
    glActiveTexture(GL_TEXTURE0);
    [self.backBufferTexture use];
    glUniform1i([sprogram uniformIndex:@"sampler2d"], 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)renderFullBG {
    glClear(GL_COLOR_BUFFER_BIT);
    glBlendFunc(GL_ONE, GL_NONE);
    FGLKProgram *sprogram = [self genProgram:@"blit" :@"blit"];
    [sprogram use];
    [self bindBuffer:Vertices3];
    glActiveTexture(GL_TEXTURE0);
    [self.backBufferTexture use];
    glUniform1i([sprogram uniformIndex:@"sampler2d"], 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

-(void)setupTexture{
//    self.curBrush = [[self.brushConfig objectForKey:@"2"] mutableCopy];
//    [self fragileTexture:[self.curBrush[@"row"] intValue] :[self.curBrush[@"line"] intValue]];
    //    CGRect rect = self.BGRect;
//    NSData *fragmentData = [self imageDataInRect:CGRectMake(0, 0, backingWidth, backingHeight)];
    //    self.bufferTexture = [GLTexture textureWithCGImage:[self imageForData:self.fragmentData size:rect.size]];
//    self.backBufferTexture = [GLTexture textureWithCGImage:[self imageForData:self.fragmentData size:CGSizeMake(backingWidth, backingHeight)]];
//    self.bufferTexture = [GLTexture textureWithCGImage:[self imageForData:self.fragmentData size:CGSizeMake(backingWidth, backingHeight)]];
    //    [self renderFullBG];
    //    self.bufferTexture = [GLTexture textureWithCGImage:];
    //    [self upFragmentData];
//    self.bufferTexture = [GLTexture textureWithCGImage:[self imageForData:self.fragmentData size:CGSizeMake(backingWidth, backingHeight)]];
}

- (CGImageRef) imageForData:(NSData *)data size:(CGSize)size
{
    size_t width = size.width;
    size_t height = size.height;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate((void *) data.bytes, width, height, 8, width*4,
                                             colorSpaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
    return imageRef;
}

-(void)setBrush:(CLImageToolInfo *)toolInfo{
    if ([EAGLContext currentContext] != self.context) {
        [EAGLContext setCurrentContext:self.context];
    }
    self.curToolInfo = toolInfo;
    self.curBrush = [toolInfo.optionalInfo mutableCopy];
    if(self.curBrush[@"row"]){
        [self fragileTexture:[self.curBrush[@"row"] intValue] :[self.curBrush[@"line"] intValue]];
    }
    [self setupBlend:self.curBrush[@"type"]];
    self.brushTextue = [GLTexture textureWithFile:self.curBrush[@"texture"]];
    
    if([self.curBrush[@"type"] intValue] >= 10 && [self.curBrush[@"type"] intValue] < 20){
//        [self setupPe];
    }else if([self.curBrush[@"type"] intValue] >= 30 && [self.curBrush[@"type"] intValue] < 40){
//        [self setupAnimation];
    }else if([self.curBrush[@"type"] intValue] == 102){
 
    }
}

-(void)fragileTexture:(int)row :(int)line{
    self.subTextureWRatio = 1.0 / (float)row;
    self.subTextureHRatio = 1.0 / (float)line;
    self.subTextureHWRatio = self.subTextureHRatio / self.subTextureWRatio;
    self.textureVector = [NSMutableArray new];
    for (int i =0 ; i < line; i++) {
        float fi = (float)i;
        for (int j = 0 ; j < row; j++) {
            float fj = (float)j;
            TextureVector4 item = {{self.subTextureWRatio * fj,self.subTextureHRatio * fi},{self.subTextureWRatio * (fj+1),self.subTextureHRatio * fi},{self.subTextureWRatio * fj,self.subTextureHRatio * (fi + 1)},{self.subTextureWRatio * (fj+1),self.subTextureHRatio * (fi + 1)}};
            //            [self.textureVector addObject:item];
            NSValue *value = [NSValue value:&item withObjCType:@encode(TextureVector4)];
            [self.textureVector addObject:value];
        }
    }
}

- (void)setupBlend:(NSString*)type{
    //    glDisable(GL_BLEND);
    //    glColorMask(false,false,false,false);
    //    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,GL_ONE , GL_ZERO);
    if([type intValue]%10 == 1){
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    }else if([type intValue]%10  == 2){
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }else if([type intValue]%10  == 3){
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }else if([type intValue]%10  == 4){
        glBlendFunc(GL_ONE, GL_ZERO);
    }else if([type intValue]%10  == 5){
        glBlendFunc(GL_ONE, GL_ONE);
    }else if([type intValue]%10  == 6){
        glBlendFunc(GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }else if([type intValue]%10  == 7){
        glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE);
    }else if([type intValue]%10  == 8){
        glBlendFunc(GL_ONE, GL_NONE);
    }else if([type intValue]%10  == 9){
        //        glBlendFuncSeparate( GL_ONE, GL_ONE, GL_ONE, GL_NONE );
        //        glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD );
        glBlendFunc(GL_ONE, GL_ONE);
    }else{
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    //   glBlendFunc(GL_SRC_ALPHA, GL_ONE);
}

-(void)setupTimer:(TIMERTYPE)type{
    if(type == SPIRIT){
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSpirit)];
    }else if(type == ANIMATION){
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateAnimation)];
    }
    
    self.displayLink.frameInterval = 1;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.timeBegin = [NSDate timeIntervalSinceReferenceDate];
}

-(void)invalidateTimer{
    self.displayLink.paused = YES;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

-(void)setupAnimation{
    self.program = [self genProgram:self.curBrush[@"v"] :self.curBrush[@"f"]];
    [self.program use];
    [self bindBuffer:Vertices3];
    glActiveTexture(GL_TEXTURE0);
    [self.backBufferTexture use];
    glUniform1i([self.program uniformIndex:@"sampler2d"], 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self setupTimer:ANIMATION];
    return;
}

- (void)updateAnimation{
    self.changed = YES;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    glUniform1f([self.program uniformIndex:@"u_time"], now - self.timeBegin);
    glActiveTexture(GL_TEXTURE0);
    [self.backBufferTexture use];
    glUniform1i([self.program uniformIndex:@"sampler2d"], 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

-(void)setupPe{
    NSData *fragmentData = [self imageDataInRect:self.BGRect];
//    if(!self.backBufferTexture){
//        self.backBufferTexture = [GLTexture textureWithCGImage:[self imageForData:fragmentData size:self.BGRect.size]];
//    }
//    [self.backBufferTexture use];
//    glTexSubImage2D(GL_TEXTURE_2D,0,self.BGRect.origin.x,self.BGRect.origin.y, self.BGRect.size.width, self.BGRect.size.height, GL_RGBA, GL_UNSIGNED_BYTE,fragmentData.bytes);
    
    [self.displayLink invalidate];
    //    self.curPe += 1;
    self.particleEmitterEffect = [[GLKBaseEffect alloc] init];
    self.particleEmitterEffect.texture2d0.envMode = GLKTextureEnvModeModulate;
    self.particleEmitterEffect.useConstantColor = GL_FALSE;
    self.particleEmitterEffect.transform.projectionMatrix = GLKMatrix4MakeOrtho(0,backingWidth, 0, backingHeight, 0, 1);
    
    _pe = [[ParticleEmitter alloc] init];
    _pe.curBrush = self.curBrush;
    if(self.curBrush[@"texture"]){
        _pe.textureFile = self.curBrush[@"texture"];
        _pe.texturePositions = self.textureVector;
    }
    [_pe setupParticleEmitterWithFile :self.curBrush[@"file"] effectShader:self.particleEmitterEffect scale:self.contentScaleFactor];
    _pe.sourcePosition = GLKVector2Make(self.endPoint.x,self.endPoint.y);
    _pe.reusableFramebuffer = _frameBuffer;
    [_pe reset];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    self.timeSinceLastUpdate = now;
    [self setupTimer:SPIRIT];
}

- (void)updateSpirit
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
//    if(now - self.timeBegin > 20){
//        [self.displayLink invalidate];
//        [self scissor];
//        return;
//    }
    self.changed = YES;
    [self renderFullBG];
    [self setupBlend:self.curBrush[@"type"]];
    [_pe renderParticles];
    [_pe updateWithDelta:now - self.timeSinceLastUpdate :now - self.self.timeBegin];
    [self display];
    self.timeSinceLastUpdate = now;
}

-(void)display{
    [EAGLContext setCurrentContext:_context];
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)pan:(UIPanGestureRecognizer *)pan {
    if(!self.curBrush){
        return;
    }
    
    CGPoint currentPoint = [pan locationInView:self];
    CGPoint velocity = [pan velocityInView:self];
//    if(CGPointEqualToPoint(currentPoint,CGPointMake(0, 0))){
//        NSLog(@"0 0 %ld" ,(long)pan.state);
//        return;
//    }
    
    if (pan.state == UIGestureRecognizerStateBegan) {
//        self.endPoint = CGPointMake(location.x * self.screenScale, location.y * self.screenScale);
        self.endPoint = CGPointMake(currentPoint.x * self.contentScaleFactor, currentPoint.y * self.contentScaleFactor);
        self.lastDrawRect = CGRectZero;
        self.changed = NO;
        firstTouch = YES;
        [self setupBlend:self.curBrush[@"type"]];
        if([self.curBrush[@"type"] intValue] >= 10 && [self.curBrush[@"type"] intValue] < 20){
            if(!self.beginSpirit){
                [self setupPe];
                self.beginSpirit = YES;
            }
        }else if([self.curBrush[@"type"] intValue] >= 30 && [self.curBrush[@"type"] intValue] < 40){
            if(!self.beginAnimatio){
                [self setupAnimation];
                self.beginAnimatio = YES;
            }
        }
        [self renderLineFromPoint:currentPoint toPoint:currentPoint state:pan.state velocity:velocity];
    }else if (pan.state == UIGestureRecognizerStateChanged){
        [self renderLineFromPoint:previousLocation toPoint:currentPoint state:pan.state velocity:velocity];
    }else if (pan.state == UIGestureRecognizerStateEnded){
//        [self renderLineFromPoint:previousLocation toPoint:currentPoint state:pan.state velocity:velocity];
        self.curPe += 1;
        self.program = nil;
        self.beginAnimatio = NO;
        self.beginSpirit = NO;
        [self invalidateTimer];
        [self scissor];
        [self upFragmentData];
    }
    
    previousLocation = currentPoint;
}


// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end state:(UIGestureRecognizerState)state velocity:(CGPoint)velocity
{
    start.y = [self bounds].size.height - start.y;
    end.y = [self bounds].size.height - end.y;
    CGFloat scale = self.screenScale;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    if(state == UIGestureRecognizerStateBegan){
        self.endPoint = end;
        return;
    }
    
    CGFloat brushSize = [self.curBrush[@"size"] floatValue] * scale;
 
    //10-20 粒子效果 , 30-40 动画效果 40-50涂抹(背景色)
    if([self.curBrush[@"type"] intValue] >= 10 && [self.curBrush[@"type"] intValue] < 20){
        _pe.sourcePosition = GLKVector2Make(end.x, end.y);
        return;
    }
    if([self.curBrush[@"type"] intValue] >= 30 && [self.curBrush[@"type"] intValue] < 40){
        glUniform2f([self.program uniformIndex:@"mouse"], end.x, end.y);
        return;
    }
    
    FGLKProgram *sprogram = [self genProgram:self.curBrush[@"v"] :self.curBrush[@"f"]];
    GLint currProgram;
    glGetIntegerv(GL_CURRENT_PROGRAM, &currProgram);
    if(currProgram != [sprogram name]){
        [sprogram use];
    }
    
    int BrushPixelStep = MAX(2, brushSize * [self.curBrush[@"step"] floatValue]);
 
    self.changed = YES;
    
    int count = MAX(ceilf(sqrtf((end.x -  self.endPoint.x) * (end.x - self.endPoint.x) + (end.y - self.endPoint.y) * (end.y - self.endPoint.y)) / BrushPixelStep), 1.0);
 
    if(count < 2){
        return;
    }
    CGFloat radian = radianBetweenLinesInDegrees(self.endPoint, CGPointMake(end.x, self.endPoint.y), self.endPoint, end);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    glUniformMatrix4fv([sprogram uniformIndex:@"MVP"], 1, GL_FALSE, MVPMatrix.m);
    GLKVector4 vColor = GLKVector4Make(self.brushColor.red,self.brushColor.green,self.brushColor.blue,1.0);
    
//    float startPenThickness = previousThickness;
//    float endPenThickness = penThickness;
    previousThickness = penThickness;
    /*
     //不使用不要加
     "direction":  "1"
     "scale": 0.8,
     "rotate": 0,
     */
    NSLog(@"start %@ %@",NSStringFromCGPoint(self.endPoint),NSStringFromCGPoint(end) );

    for(int i = 0; i < count; ++i) {
        CGRect rect = CGRectMake(self.endPoint.x + (end.x - self.endPoint.x) * ((GLfloat)i / (GLfloat)count) - brushSize / 2 , self.endPoint.y + (end.y - self.endPoint.y) * ((GLfloat)i / (GLfloat)count) - brushSize / 2, brushSize , brushSize * self.subTextureHWRatio );
//        return;
//        penThickness = startPenThickness + ((endPenThickness - startPenThickness) / count) * i;
 
        TranVertex v;
        if(self.curBrush[@"direction"]){
            v = [self transform:rect :radian :1.];
            rect = v.rect;
        }else{
            v = [self transform:rect :0 :1.];
            radian = 0.;
        }
        
        if(self.curBrush[@"scale"] && self.curBrush[@"rotate"]){
            CGFloat rotate = RandomFloatBetween([self.curBrush[@"rotate"] floatValue] * M_PI, [self.curBrush[@"rotate"] floatValue] * -M_PI ) + radian;
            CGFloat scale = RandomFloatBetween([self.curBrush[@"scale"] floatValue], 1./[self.curBrush[@"scale"] floatValue]);
            v = [self transform:rect :rotate :scale];
        }
        
        int rnd = RandomUIntBelow([self.textureVector count] - 1.);
        NSValue *value = [self.textureVector objectAtIndex:rnd];
        TextureVector4 textureV;
        [value getValue:&textureV];
        
        if([self.curBrush[@"type"] intValue] >= 40 && [self.curBrush[@"type"] intValue] < 50){
            UIColor *aColor = [self getBgColorWithRect:rect];
            CGFloat r, g, b, a;
            [aColor getRed: &r green:&g blue:&b alpha:&a];
            vColor = GLKVector4Make(r,g,b,a);
        }
        
        Vertex Vertices4[] = {
            {{v.point[0].x,v.point[0].y,0},{vColor.r,vColor.g,vColor.b,vColor.a},{textureV.bl.x,textureV.bl.t}},
            {{v.point[1].x,v.point[1].y,0},{vColor.r,vColor.g,vColor.b,vColor.a},{textureV.br.x,textureV.br.t}},
            {{v.point[2].x,v.point[2].y,0},{vColor.r,vColor.g,vColor.b,vColor.a},{textureV.tl.x,textureV.tl.t}},
            {{v.point[3].x,v.point[3].y,0},{vColor.r,vColor.g,vColor.b,vColor.a},{textureV.tr.x,textureV.tr.t}}
        };
        [self bindBuffer:Vertices4];
        
        glActiveTexture(GL_TEXTURE0);
        [self.brushTextue use];
        glUniform1i([sprogram uniformIndex:@"sampler2d"], 0);
        glActiveTexture(GL_TEXTURE1);
        [self.backBufferTexture use];
        
        //        glBindFramebuffer(GL_FRAMEBUFFER, depthRenderbuffer);
        //        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,GL_TEXTURE_2D, self.brushTextue.textureName, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, _renderBuffer);
        glUniform1i([sprogram uniformIndex:@"backbuffer"], 1);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//        break;
    }

    self.endPoint = end;
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)addTriangleStripPointsForPrevious:(PPSSignaturePoint)previous next:(PPSSignaturePoint)next {
    float toTravel = penThickness / 2.0;
    
    for (int i = 0; i < 2; i++) {
        GLKVector3 p = perpendicular(previous, next);
        GLKVector3 p1 = next.vertex;
        GLKVector3 ref = GLKVector3Add(p1, p);
        
        float distance = GLKVector3Distance(p1, ref);
        float difX = p1.x - ref.x;
        float difY = p1.y - ref.y;
        float ratio = -1.0 * (toTravel / distance);
        
        difX = difX * ratio;
        difY = difY * ratio;
        
        PPSSignaturePoint stripPoint = {
            { p1.x + difX, p1.y + difY, 0.0 },
            StrokeColor
        };
        addVertex(&length, stripPoint);
        toTravel *= -1;
    }
}

CGFloat radianBetweenLinesInDegrees(CGPoint beginLineA,
                                    CGPoint endLineA,
                                    CGPoint beginLineB,
                                    CGPoint endLineB){
    CGFloat a = endLineA.x - beginLineA.x;
    CGFloat b = endLineA.y - beginLineA.y;
    CGFloat c = endLineB.x - beginLineB.x;
    CGFloat d = endLineB.y - beginLineB.y;
    
    CGFloat atanA = atan2(a, b);
    CGFloat atanB = atan2(c, d);
    return (atanA - atanB);
}

-(UIColor*)getBgColorWithRect:(CGRect)rect{
    CGPoint point = CGPointMake((rect.origin.x - (1.0-self.bgImgWUseRatio)/2 * backingWidth) * (self.mainImage.size.width/(backingWidth * self.bgImgWUseRatio)) + rect.size.width/2,
                                (rect.origin.y - (1.0-self.bgImgHUseRatio)/2 * backingHeight) * (self.mainImage.size.height/(backingHeight * self.bgImgHUseRatio)) + rect.size.height/2
                                );
    point = CGPointMake(MIN(self.mainImage.size.width, MAX(point.x,0)) , MIN(self.mainImage.size.height, MAX(point.y,0)));
//    NSLog(@"pint %@",NSStringFromCGPoint(point));
//    return [UIColor redColor];
    NSUInteger bytesPerRow = 4 * self.mainImage.size.width;
    int startY = self.mainImage.size.height - (int)point.y;
    
    int red   = 0;
    int green = 0;
    int blue  = 0;
    int alpha = 0;
    
    for(int y = -5; y < 5; y++)
    {
        int curY = MAX(MIN(startY + y, self.mainImage.size.height -1),0) ;
        for(int x = -5; x < 5; x++)
        {
            NSUInteger curx = MAX(MIN((int)point.x + x,self.mainImage.size.width - 1), 0);
            NSUInteger pixelInfo = ((bytesPerRow * curY)) + curx * 4;
            red   += self.backBufferTexture.data_[pixelInfo];
            green += self.backBufferTexture.data_[pixelInfo + 1];
            blue  += self.backBufferTexture.data_[pixelInfo + 2];
            alpha += self.backBufferTexture.data_[pixelInfo + 3];
            
        }
    }
    
    UIColor *color = [UIColor colorWithRed:red /100. /255.0f
                                     green:green/100./255.0f
                                      blue:blue /100./255.0f
                                     alpha:alpha /100./255.0f];
    return color;
    //    CGImageRef imageRef = CGImageCreateWithImageInRect(self.imageRef, CGRectMake(point.x - 100, self.mainImage.size.height - point.y -100, 200, 200));
    //    [self.tempImgView setImage:[UIImage imageWithCGImage:imageRef]];
    //    CGImageRelease(imageRef);
    
    
    //    return [self randomColor];
    //    NSLog(@"pint %@",NSStringFromCGPoint(point));
    
    //
    //    int red   = 0;
    //    int green = 0;
    //    int blue  = 0;
    //    int alpha = 0;
    //
    //    int start = (self.mainImage.size.width *(self.mainImage.size.height - (int)point.y));
    //    for(int y = -5; y < 5; y++)
    //    {
    //        int curY = MAX(MIN((self.mainImage.size.height - (int)point.y + y), self.mainImage.size.height - 1),0) ;
    //        for(int x = -5; x < 5; x++)
    //        {
    //
    //            int pixelInfo = ((self.mainImage.size.width * curY) + MAX(MIN((int)point.x + x,self.mainImage.size.width -1 ), 0) ) * 4;
    //            red   += self.byteData[pixelInfo + 0];
    //            green += self.byteData[pixelInfo + 1];
    //            blue  += self.byteData[pixelInfo + 2];
    //            alpha += self.byteData[pixelInfo + 3];
    //
    //        }
    //    }
    //    //    int pixelInfo = ((self.mainImage.size.width *(self.mainImage.size.height - (int)point.y)) + (int)point.x ) * 4;// 4 bytes per pixel
    //
    //    //    UInt8 red   = self.byteData[pixelInfo + 0];
    //    //    UInt8 green = self.byteData[pixelInfo + 1];
    //    //    UInt8 blue  = self.byteData[pixelInfo + 2];
    //    //    UInt8 alpha = self.byteData[pixelInfo + 3];
    //    //    CFRelease(pixelData);
    //
    //    UIColor *color = [UIColor colorWithRed:red /100. /255.0f
    //                                     green:green/100./255.0f
    //                                      blue:blue /100./255.0f
    //                                     alpha:1.0];
    //
    //    [self.tempImgView setBackgroundColor:color];
    //    return color;
    //    CGPoint point = CGPointMake((self.mainImage.size.width/backingWidth) * rect.origin.x + rect.size.width/2,
    //                                (rect.origin.y - (1.0-self.bgImgHUseRatio)/2 * backingHeight) * (self.mainImage.size.height/(backingHeight * self.bgImgHUseRatio)) + rect.size.height/2
    //                                );
    //    point = CGPointMake(MIN(self.mainImage.size.width, MAX(point.x,0)) , MIN(self.mainImage.size.height, MAX(point.y,0)));
    //
    //
    //    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    //    unsigned char rgba[4];
    //    CGContextRef context = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    //
    //    CGContextDrawImage(context, CGRectMake(point.x, self.mainImage.size.height - point.y, 1, 1), self.imageRef);
    //    CGColorSpaceRelease(colorSpace);
    //    CGContextRelease(context);
    //
    //    CGFloat alpha = ((CGFloat)rgba[3])/255.0;
    //    CGFloat multiplier = alpha/255.0;
    //    UIColor *color =  [UIColor colorWithRed:((CGFloat)rgba[0])*multiplier
    //                           green:((CGFloat)rgba[1])*multiplier
    //                            blue:((CGFloat)rgba[2])*multiplier
    //                           alpha:alpha];
    //    [self.tempImgView setBackgroundColor:color];
    //    return color;
    
    //    NSLog(@"pint %@",NSStringFromCGPoint(point));
    ////    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    ////    const UInt8* data = CFDataGetBytePtr(pixelData);
    //
    //    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.mainImage.CGImage));
    //    const UInt8* data = CFDataGetBytePtr(pixelData);
    //    int pixelInfo = (self.mainImage.size.width  * (self.mainImage.size.height - (int)point.y) + (int)point.x ) * 4; // 4 bytes per pixel
    //
    //    int red   = data[pixelInfo];
    //    int green = data[pixelInfo + 1];
    //    int blue  = data[pixelInfo + 2];
    //    int alpha = data[pixelInfo + 3];
    //    CFRelease(pixelData);
    //
    //    UIColor *color = [UIColor colorWithRed:red /255.0f
    //                                     green:green/255.0f
    //                                      blue:blue/255.0f
    //                                     alpha:alpha/255.0f];
    //
    //    [self.tempImgView setBackgroundColor:color];
    //    return color;
    
    //        CGImageRef imageRef = CGImageCreateWithImageInRect(self.imageRef, CGRectMake(point.x - 100, self.mainImage.size.height - point.y -100, 200, 200));
    //        [self.tempImgView setImage:[UIImage imageWithCGImage:imageRef]];
    //        CGImageRelease(imageRef);
    
    
    //    return [self randomColor];
    //    NSLog(@"pint %@",NSStringFromCGPoint(point));
    
    
    //    int red   = 0;
    //    int green = 0;
    //    int blue  = 0;
    //    int alpha = 0;
    //
    //    for(int y = -5; y < 5; y++)
    //    {
    //        int curY = MAX(MIN((self.mainImage.size.height - (int)point.y + y), self.mainImage.size.height - 1),0) ;
    //        for(int x = -5; x < 5; x++)
    //        {
    //            int pixelInfo = ((self.mainImage.size.width * curY) + MAX(MIN((int)point.x + x,self.mainImage.size.width -1 ), 0) ) * 4;
    //            red   += self.byteData[pixelInfo + 0];
    //            green += self.byteData[pixelInfo + 1];
    //            blue  += self.byteData[pixelInfo + 2];
    //            alpha += self.byteData[pixelInfo + 3];
    //        }
    //    }
    //        int pixelInfo = (self.mainImage.size.width * (self.mainImage.size.height - (int)point.y) + point.x ) * 4;
    //        UInt8 red   = self.byteData[pixelInfo + 0];
    //        UInt8 green = self.byteData[pixelInfo + 1];
    //        UInt8 blue  = self.byteData[pixelInfo + 2];
    //        UInt8 alpha = self.byteData[pixelInfo + 3];
    ////        CFRelease(pixelData);
    //
    //        UIColor *color = [UIColor colorWithRed:red /255.0f
    //                                         green:green/255.0f
    //                                          blue:blue/255.0f
    //                                         alpha:alpha/255.0f];
    //
    //    UIColor *color = [UIColor colorWithRed:red /100. /255.0f
    //                                     green:green/100./255.0f
    //                                      blue:blue /100./255.0f
    //                                     alpha:alpha/255.0f];
    
    //    [self.tempImgView setBackgroundColor:color];
    //    return color;
}

-(TranVertex)transform:(CGRect)rect :(CGFloat)rotate :(CGFloat)scale{
    CGPoint corners[4];
    corners[0] = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
    corners[1] = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    corners[2] = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
    corners[3] = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
    
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGAffineTransform t = CGAffineTransformMakeTranslation(center.x, center.y);
    t = CGAffineTransformRotate(t, rotate);
    t = CGAffineTransformScale(t,scale,scale);
    t = CGAffineTransformTranslate(t, -center.x, -center.y);
    
    CGRect tranedRect =  CGRectApplyAffineTransform(rect, t);
    tranedRect.size.width  = (int)tranedRect.size.width;
    tranedRect.size.height  = (int)tranedRect.size.height;
    
    for (int i = 0; i < 4; i++) {
        corners[i] = CGPointApplyAffineTransform(corners[i], t);
    }
    TranVertex v = {tranedRect,{corners[0],corners[1],corners[2],corners[3]}};
    return v;
}

-(void)scissor{
    glEnable(GL_SCISSOR_TEST);
    if(self.bgImgWUseRatio == 1.0){
        glScissor(0, (float)backingHeight * ((1 - self.bgImgHUseRatio)/2 + self.bgImgHUseRatio), backingWidth, backingHeight * self.bgImgHUseRatio / 2);
        glClear(GL_COLOR_BUFFER_BIT);
        glScissor(0, 0, backingWidth, backingHeight * ((1 - self.bgImgHUseRatio) / 2));
        glClear(GL_COLOR_BUFFER_BIT);
    }else{
        glScissor((float)backingWidth * ((1 - self.bgImgWUseRatio)/2 + self.bgImgWUseRatio), 0, backingWidth  * (1 - self.bgImgWUseRatio) / 2, backingHeight);
        glClear(GL_COLOR_BUFFER_BIT);
        glScissor(0, 0, backingWidth  * (1 - self.bgImgWUseRatio) / 2,  backingHeight);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    glDisable(GL_SCISSOR_TEST);
}

- (NSData *) imageDataInRect:(CGRect)rect
{
    NSData *result = nil;
    GLint minX = (GLint) CGRectGetMinX(rect);
    GLint minY = (GLint) CGRectGetMinY(rect);
    GLint width = (GLint) CGRectGetWidth(rect);
    GLint height = (GLint) CGRectGetHeight(rect);
    
    // color buffer should now have layer contents
    NSInteger myDataLength = width * height * 4;
    UInt8 *buffer = malloc(myDataLength);
    glReadPixels(minX, minY, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    
    GLubyte *buffer2 = (GLubyte *) malloc(myDataLength);
    for(int y = 0; y < height; y++)
    {
        for(int x = 0; x < width * 4; x++)
        {
            buffer2[(height - y - 1) * width * 4 + x] = buffer[y * 4 * width + x];
        }
    }
    
    result = [NSData dataWithBytes:buffer2 length:myDataLength];
    free(buffer);
    free(buffer2);
    //WDCheckGLError();
    return result;
}

-(UIImage *) glToUIImage {
    NSInteger myDataLength = backingWidth * backingHeight * 4;
    // allocate array and read pixels into it.
    GLubyte *buffer = (GLubyte *) malloc(myDataLength);
    glReadPixels(0, 0, backingWidth, backingHeight, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    
    GLubyte *buffer2 = (GLubyte *) malloc(myDataLength);
    for(int y = 0; y < backingHeight; y++)
    {
        for(int x = 0; x < backingWidth * 4; x++)
        {
            buffer2[(backingHeight - y) * backingWidth * 4 + x] = buffer[y * 4 * backingWidth + x];
        }
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, myDataLength, NULL);
    
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * backingWidth;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(backingWidth, backingHeight, bitsPerComponent, bitsPerPixel, bytesPerRow,     colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    return [UIImage imageWithData:UIImagePNGRepresentation([UIImage imageWithCGImage:imageRef])];
}

- (GLuint) generateTexture:(GLubyte *)pixels deepColor:(BOOL)deepColor
{
    [EAGLContext setCurrentContext:self.context];
    WDCheckGLError();
    GLuint      textureName;
    glGenTextures(1, &textureName);
    glBindTexture(GL_TEXTURE_2D, textureName);
    // Set up filter and wrap modes for this texture object
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    GLuint      width = (GLuint) backingWidth;
    GLuint      height = (GLuint) backingHeight;
    GLenum      format = GL_RGBA;
    GLenum      type = deepColor ? GL_HALF_FLOAT_OES : GL_UNSIGNED_BYTE;
    NSUInteger  bytesPerPixel = deepColor ? 8 : 4;
    
    if (!pixels) {
        pixels = calloc((size_t) (backingWidth * bytesPerPixel * backingHeight), sizeof(GLubyte));
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, type, pixels);
        free(pixels);
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, type, pixels);
    }
    
    WDCheckGLError();
    return textureName;
}

-(void)undo{
    if(![self.undoManager canUndo]){
        return;
    }
    [self.undoManager undo];
}

-(void)redo{
    if(![self.undoManager canRedo]){
        return;
    }
    [self.undoManager redo];
}

- (void) registerUndoWith:(NSData *)data
{
    CGRect rect = self.BGRect;
    WDPaintingFragment *fragment = [WDPaintingFragment paintingFragmentWithData:data bounds:rect];
    [[self.undoManager prepareWithInvocationTarget:self] drawFragment:fragment];
}

- (void) drawFragment:(WDPaintingFragment *)fragment
{
    [[self.undoManager prepareWithInvocationTarget:self] drawFragment:fragment];
    [fragment applyInLayer:self.backBufferTexture.textureName];
    [self renderFullBG];
    [self display];
}

-(void)upFragmentData{
    CGRect rect = self.BGRect;
    [self.backBufferTexture use];
    NSData *fragmentData = [self imageDataInRect:rect];
//    if(!self.backBufferTexture){
//        self.backBufferTexture = [GLTexture textureWithCGImage:[self imageForData:self.fragmentData size:self.BGRect.size]];
//    }
    //截取fragmentData
    glTexSubImage2D(GL_TEXTURE_2D,0,rect.origin.x,rect.origin.y, rect.size.width, rect.size.height, GL_RGBA, GL_UNSIGNED_BYTE, fragmentData.bytes);
//    if(self.fragmentData){
//        [self registerUndoWith:self.fragmentData];
//    }
//    CGRect rect = self.BGRect;
//    
//    self.fragmentData = [self imageDataInRect:rect];
//    if(!self.backBufferTexture){
//        self.backBufferTexture = [GLTexture textureWithCGImage:[self imageForData:self.fragmentData size:self.BGRect.size]];
//    }
//    [self.backBufferTexture use];
////    //截取fragmentData
//    glTexSubImage2D(GL_TEXTURE_2D,0,rect.origin.x,rect.origin.y, rect.size.width, rect.size.height, GL_RGBA, GL_UNSIGNED_BYTE, self.fragmentData.bytes);
//    if(fragmentData){
//        [self registerUndoWith:fragmentData];
//    }
//    fragmentData = nil;
}

-(UIImage *)capture{
    CGRect rect = self.BGRect;
    NSData *fragmentData = [self imageDataInRect:rect];
    return [[UIImage alloc] initWithCGImage:[self imageForData:fragmentData size:self.BGRect.size]];
}


//de
-(void)signatureDrawEnd:(UIImage *)image{
    [EAGLContext setCurrentContext:_context];
    self.tempImgView.image = image;
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    FGLKProgram *sprogram = [self genProgram:@"blit" :@"blit"];
    [sprogram use];
    [self bindBuffer:Vertices3];
    glActiveTexture(GL_TEXTURE0);
    GLTexture *texture = [GLTexture textureWithImage:image];
    [texture use];
    glUniform1i([sprogram uniformIndex:@"sampler2d"], 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self display];
    [self scissor];
    [self upFragmentData];
}


-(void)dealloc{
    self.sourceTexture  = nil;
    [EAGLContext setCurrentContext:nil];
    self.context = nil;
    free(self.rawData);
    self.backBufferTexture = nil;
    glDeleteBuffers(1, &(_frameBuffer));
    glDeleteBuffers(1, &(_renderBuffer));
    glDeleteBuffers(1, &(vertexBuffer));
}
@end
