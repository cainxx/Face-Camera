

#import <UIKit/UIKit.h>
#import "CLImageToolInfo.h"
#import "SignatureViewQuartzQuadratic.h"

@interface ESView : UIView<signatureViewDrawEndDelegate>{
    // The pixel dimensions of the backbuffer
    GLint backingWidth;
    GLint backingHeight;

    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer, viewFramebuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;
 
    GLfloat brushColor[4];          // brush color
    
    Boolean	firstTouch;
    Boolean needsErase;
    
    // Shader objects
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint shaderProgram;
    
    // Buffer Objects
    GLuint vboId;
    
    GLuint vertexBuffer;
    BOOL initialized;
}

@property(nonatomic, readwrite) CGPoint location;
@property(nonatomic, readwrite) CGPoint previousLocation;
@property(nonatomic) UIImage *mainImage;
@property (nonatomic, weak)SignatureViewQuartzQuadratic *signatureView;
//-(void)clean;
-(void)setBrush:(CLImageToolInfo *)toolInfo;
- (NSData *) imageDataInRect:(CGRect)rect;
-(void)undo;
-(void)redo;

@end
