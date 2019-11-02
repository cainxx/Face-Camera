//
//  BCMeshTransform.m
//  BCMeshTransformView
//
//  Copyright (c) 2014 Bartosz Ciechanowski. All rights reserved.
//

#import "MSTransform.h"

#import <vector>

NSString * const kBCDepthNormalizationNone = @"none";
NSString * const kBCDepthNormalizationWidth = @"width";
NSString * const kBCDepthNormalizationHeight = @"height";
NSString * const kBCDepthNormalizationMin = @"min";
NSString * const kBCDepthNormalizationMax = @"max";
NSString * const kBCDepthNormalizationAverage = @"average";


@interface MSTransform()
{
    @protected
    // Performance really matters here, CAMeshTransform makes use of vectors as well
    std::vector<BCMeshFace> _faces;
    std::vector<BCMeshVertex> _vertices;
}

@property (nonatomic, copy, readwrite) NSString *depthNormalization;

@end


@implementation MSTransform

+ (instancetype)meshTransformWithVertexCount:(NSUInteger)vertexCount
                                    vertices:(BCMeshVertex *)vertices
                                   faceCount:(NSUInteger)faceCount
                                       faces:(BCMeshFace *)faces
                          depthNormalization:(NSString *)depthNormalization
{
    return [[self alloc] initWithVertexCount:vertexCount
                                    vertices:vertices
                                   faceCount:faceCount
                                       faces:faces
                          depthNormalization:depthNormalization];
}

- (instancetype)init
{
    return [self initWithVertexCount:0
                            vertices:NULL
                           faceCount:0
                               faces:NULL
                  depthNormalization:kBCDepthNormalizationNone];
}

- (instancetype)initWithVertexCount:(NSUInteger)vertexCount
                           vertices:(BCMeshVertex *)vertices
                          faceCount:(NSUInteger)faceCount
                              faces:(BCMeshFace *)faces
                 depthNormalization:(NSString *)depthNormalization
{
    self = [super init];
    if (self) {
        
        _vertices = std::vector<BCMeshVertex>();
        _vertices.reserve(vertexCount);
        
        _faces = std::vector<BCMeshFace>();
        _faces.reserve(faceCount);
        
        for (int i = 0; i < vertexCount; i++) {
            _vertices.push_back(vertices[i]);
        }

        for (int i = 0; i < faceCount; i++) {
            _faces.push_back(faces[i]);
        }
        
        self.depthNormalization = depthNormalization;
    }
    return self;
}

- (id)copyWithClass:(Class)cls
{
    MSTransform *copy = [cls new];
    copy->_depthNormalization = _depthNormalization;
    copy->_vertices = std::vector<BCMeshVertex>(_vertices);
    copy->_faces = std::vector<BCMeshFace>(_faces);
    
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self copyWithClass:[MSTransform class]];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithClass:[MSMutableTransform class]];
}


- (NSUInteger)faceCount
{
    return _faces.size();
}

- (NSUInteger)vertexCount
{
    return _vertices.size();
}

- (BCMeshFace)faceAtIndex:(NSUInteger)faceIndex
{
    NSAssert(faceIndex < _faces.size(), @"Requested faceIndex (%lu) is larger or equal to number of faces (%lu)", (unsigned long)faceIndex, _faces.size());
    
    return _faces[faceIndex];
}

- (BCMeshVertex)vertexAtIndex:(NSUInteger)vertexIndex
{
    NSAssert(vertexIndex < _vertices.size(), @"Requested vertexIndex (%lu) is larger or equal to number of vertices (%lu)", (unsigned long)vertexIndex, _vertices.size());
    
    return _vertices[vertexIndex];
}

@end


@implementation MSMutableTransform

+ (instancetype)meshTransform
{
    return [[self alloc] init];
}

+ (instancetype)identityMeshTransformWithNumberOfRows:(NSUInteger)rowsOfFaces
                                      numberOfColumns:(NSUInteger)columnsOfFaces
{
    NSParameterAssert(rowsOfFaces >= 1);
    NSParameterAssert(columnsOfFaces >= 1);
    
    MSMutableTransform *transform = [MSMutableTransform new];
    

    for (int row = 0; row <= rowsOfFaces; row++) {
        
        for (int col = 0; col <= columnsOfFaces; col++) {
            
            CGFloat x = (CGFloat)col/(columnsOfFaces);
            CGFloat y = (CGFloat)row/(rowsOfFaces);
            
            BCMeshVertex vertex = {
                .from = {x, y},
                .to = {x, y, 0.0f}
            };
            
            [transform addVertex:vertex];
        }
    }
    
    for (int row = 0; row < rowsOfFaces; row++) {
        for (int col = 0; col < columnsOfFaces; col++) {
            BCMeshFace face = {
                .indices = {
                    (unsigned int)((row + 0) * (columnsOfFaces + 1) + col),
                    (unsigned int)((row + 0) * (columnsOfFaces + 1) + col + 1),
                    (unsigned int)((row + 1) * (columnsOfFaces + 1) + col + 1),
                    (unsigned int)((row + 1) * (columnsOfFaces + 1) + col)
                }
            };
            
            [transform addFace:face];
        }
    }
    
    transform.depthNormalization = kBCDepthNormalizationAverage;
    return transform;
}

+ (instancetype)meshTransformWithVertexCount:(NSUInteger)vertexCount
                             vertexGenerator:(BCMeshVertex (^)(NSUInteger vertexIndex))vertexGenerator
                                   faceCount:(NSUInteger)faceCount
                                       faceGenerator:(BCMeshFace (^)(NSUInteger faceIndex))faceGenerator
{
    MSMutableTransform *transform = [MSMutableTransform new];
    
    for (int i = 0; i < vertexCount; i++) {
        [transform addVertex:vertexGenerator(i)];
    }
    
    for (int i = 0; i < faceCount; i++) {
        [transform addFace:faceGenerator(i)];
    }
    
    return transform;
}

- (void)mapVerticesUsingBlock:(BCMeshVertex (^)(BCMeshVertex vertex, NSUInteger vertexIndex))block
{
    NSUInteger count = self.vertexCount;
    for (int i = 0; i < count; i++) {
        [self replaceVertexAtIndex:i withVertex:block([self vertexAtIndex:i], i)];
    }
}

- (void)addFace:(BCMeshFace)face
{
    _faces.push_back(face);
}

- (void)removeFaceAtIndex:(NSUInteger)faceIndex
{
    _faces.erase(_faces.begin() + faceIndex);
}

- (void)replaceFaceAtIndex:(NSUInteger)faceIndex withFace:(BCMeshFace)face
{
    _faces[faceIndex] = face;
}


- (void)addVertex:(BCMeshVertex)vertex
{
    _vertices.push_back(vertex);
}

- (void)removeVertexAtIndex:(NSUInteger)vertexIndex
{
    _vertices.erase(_vertices.begin() + vertexIndex);
}

- (void)replaceVertexAtIndex:(NSUInteger)vertexIndex withVertex:(BCMeshVertex)vertex
{
    _vertices[vertexIndex] = vertex;
}


@end



