//
//  BCMeshTransform.h
//  BCMeshTransformView
//
//  Copyright (c) 2014 Bartosz Ciechanowski. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct BCPoint3D {
    CGFloat x;
    CGFloat y;
    CGFloat z;
} BCPoint3D;

static inline BCPoint3D BCPoint3DMake(CGFloat x, CGFloat y, CGFloat z)
{
    return (BCPoint3D){x,y,z};
}


typedef struct BCMeshFace {
    unsigned int indices[4];
} BCMeshFace;

typedef struct BCMeshVertex {
    CGPoint from;
    BCPoint3D to;
} BCMeshVertex;


extern NSString * const kBCDepthNormalizationNone;
extern NSString * const kBCDepthNormalizationWidth;
extern NSString * const kBCDepthNormalizationHeight;
extern NSString * const kBCDepthNormalizationMin;
extern NSString * const kBCDepthNormalizationMax;
extern NSString * const kBCDepthNormalizationAverage;

@interface MSTransform : NSObject <NSCopying, NSMutableCopying>

@property (nonatomic, copy, readonly) NSString *depthNormalization; // defaults to kBCDepthNormalizationNone

@property (nonatomic, readonly) NSUInteger faceCount;
@property (nonatomic, readonly) NSUInteger vertexCount;

+ (instancetype)meshTransformWithVertexCount:(NSUInteger)vertexCount
                                    vertices:(BCMeshVertex *)vertices
                                   faceCount:(NSUInteger)faceCount
                                       faces:(BCMeshFace *)faces
                          depthNormalization:(NSString *)depthNormalization;


- (instancetype)initWithVertexCount:(NSUInteger)vertexCount
                           vertices:(BCMeshVertex *)vertices
                          faceCount:(NSUInteger)faceCount
                              faces:(BCMeshFace *)faces
                 depthNormalization:(NSString *)depthNormalization;


- (BCMeshFace)faceAtIndex:(NSUInteger)faceIndex;
- (BCMeshVertex)vertexAtIndex:(NSUInteger)vertexIndex;

@end


@interface MSMutableTransform : MSTransform

@property (nonatomic, copy) NSString *depthNormalization;

+ (instancetype)meshTransform;

// Creates rectangular mesh transform with facesRows by facesColumns faces and equally spread vertices.
// Created transform is an identity transform – it doesn't introduce any distrubances.
// Number of rows and columns must be larger or equal to 1.
+ (instancetype)identityMeshTransformWithNumberOfRows:(NSUInteger)rowsOfFaces
                                      numberOfColumns:(NSUInteger)columnsOfFaces;


+ (instancetype)meshTransformWithVertexCount:(NSUInteger)vertexCount
                             vertexGenerator:(BCMeshVertex (^)(NSUInteger vertexIndex))vertexGenerator
                                   faceCount:(NSUInteger)faceCount
                               faceGenerator:(BCMeshFace (^)(NSUInteger faceIndex))faceGenerator;

// Enumerates over vertices and maps them to some other vertices
- (void)mapVerticesUsingBlock:(BCMeshVertex (^)(BCMeshVertex vertex, NSUInteger vertexIndex))block;

- (void)addFace:(BCMeshFace)face;
- (void)removeFaceAtIndex:(NSUInteger)faceIndex;
- (void)replaceFaceAtIndex:(NSUInteger)faceIndex withFace:(BCMeshFace)face;

- (void)addVertex:(BCMeshVertex)vertex;
- (void)removeVertexAtIndex:(NSUInteger)vertexIndex;
- (void)replaceVertexAtIndex:(NSUInteger)vertexIndex withVertex:(BCMeshVertex)vertex;

@end

