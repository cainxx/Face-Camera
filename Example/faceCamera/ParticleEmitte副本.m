//
//  ParticleEmitter.m
//  ParticleEmitterDemo
//
// Copyright (c) 2010 71Squared
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// The design and code for the ParticleEmitter were heavely influenced by the design and code
// used in Cocos2D for their particle system.

#import "ParticleEmitter.h"
#import "TBXML.h"
#import "TBXMLParticleAdditions.h"
#import "TBXML+Compression.h"
#import "GLMath.h"
#import "GLProgram.h"
#import "GLTexture.h"
#import "FGLKProgram.h"
#import "ParticleEmitter.h"
#import "GLMath.h"

#pragma mark -
#pragma mark Private interface

#define SCREEN_WIDTH [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height

typedef struct TextureVector4{
    GLKVector2 bl;
    GLKVector2 br;
    GLKVector2 tl;
    GLKVector2 tr;
} TextureVector4;

typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2];
} Vertex;

const Vertex Vertices4[] = {
    {{-1,1,0},{0,0,0,1},{0,0}},
    {{1,1,0},{0,0,0,1},{1,0}},
    {{-1,-1,0},{0,0,1,1},{0,1}},
    {{1,-1,0},{0,0,0,1},{1,1}}
};

@interface ParticleEmitter (Private)



// Adds a particle from the particle pool to the emitter
- (BOOL)addParticle;

// Initialises a particle ready for use
- (void)initParticle:(Particle*)particle;

// Parses the supplied XML particle configuration file
- (void)parseParticleConfig:(TBXML*)aConfig;

// Set up the arrays that are going to store our particles
- (void)setupArrays;

@end

#pragma mark -
#pragma mark Public implementation

@implementation ParticleEmitter

@synthesize sourcePosition;
@synthesize active;
@synthesize particleCount;
@synthesize duration;

- (void)dealloc {
	
	// Release the memory we are using for our vertex and particle arrays etc
	// If vertices or particles exist then free them
	if (quads) 
		free(quads);
    
	if (particles)
		free(particles);
    
    if (indices)
        free(indices);
	
	// Release the VBOs created
	glDeleteBuffers(1, &verticesID);
    
    // delete the texture
    GLuint name = texture.name;
    glDeleteTextures(1, &name);
}

- (void)setupParticleEmitterWithFile:(NSString*)aFileName  effectShader:(GLKBaseEffect*)aShaderEffect {
 
            shaderEffect = aShaderEffect;
            
            NSError *error;
            
			// Create a TBXML instance that we can use to parse the config file
			TBXML *particleXML = [[TBXML alloc] initWithXMLFile:aFileName error:&error];
            
            if (!error) {
                // Parse the config file
                [self parseParticleConfig:particleXML];
                [self setupArrays];
            }
 
}

- (void)updateWithDelta:(GLfloat)aDelta :(GLfloat)curDuration{

	// If the emitter is active and the emission rate is greater than zero then emit particles
	if (active && emissionRate) {
		GLfloat rate = 1.0f/emissionRate;

		if (particleCount < maxParticles)
            emitCounter += aDelta;
        
		while (particleCount < maxParticles && emitCounter > rate) {
			[self addParticle];
			emitCounter -= rate;
		}

		elapsedTime += aDelta;
        
		if (duration != -1 && duration < elapsedTime)
			[self stopParticleEmitter];
	}
	
	// Reset the particle index before updating the particles in this emitter
	particleIndex = 0;
    
    // Loop through all the particles updating their location and color
	while (particleIndex < particleCount) {

		// Get the particle for the current particle index
		Particle *currentParticle = &particles[particleIndex];
        
        // FIX 1
        // Reduce the life span of the particle
        currentParticle->timeToLive -= aDelta;
		
		// If the current particle is alive then update it
		if (currentParticle->timeToLive > 0) {
			
            // If maxRadius is greater than 0 then the particles are going to spin otherwise they are effected by speed and gravity
            if (emitterType == kParticleTypeRadial) {
                
                // FIX 2
                // Update the angle of the particle from the sourcePosition and the radius.  This is only done of the particles are rotating
                currentParticle->angle += currentParticle->degreesPerSecond * aDelta;
                currentParticle->radius += currentParticle->radiusDelta * aDelta;
                
                GLKVector2 tmp;
                tmp.x = sourcePosition.x - cosf(currentParticle->angle) * currentParticle->radius;
                tmp.y = sourcePosition.y - sinf(currentParticle->angle) * currentParticle->radius;
                currentParticle->position = tmp;
                
            } else {
                GLKVector2 tmp, radial, tangential;
                
                radial = GLKVector2Zero;
                
                // By default this emitters particles are moved relative to the emitter node position
                GLKVector2 positionDifference = GLKVector2Subtract(currentParticle->startPos, GLKVector2Zero);
                currentParticle->position = GLKVector2Subtract(currentParticle->position, positionDifference);
                
                if (currentParticle->position.x || currentParticle->position.y)
                    radial = GLKVector2Normalize(currentParticle->position);
                
                tangential = radial;
                radial = GLKVector2MultiplyScalar(radial, currentParticle->radialAcceleration);
                
                GLfloat newy = tangential.x;
                tangential.x = -tangential.y;
                tangential.y = newy;
                tangential = GLKVector2MultiplyScalar(tangential, currentParticle->tangentialAcceleration);
                
                tmp = GLKVector2Add( GLKVector2Add(radial, tangential), gravity);
                tmp = GLKVector2MultiplyScalar(tmp, aDelta);
                currentParticle->direction = GLKVector2Add(currentParticle->direction, tmp);
                tmp = GLKVector2MultiplyScalar(currentParticle->direction, aDelta);
                currentParticle->position = GLKVector2Add(currentParticle->position, tmp);
                
                // Now apply the difference calculated early causing the particles to be relative in position to the emitter position
                currentParticle->position = GLKVector2Add(currentParticle->position, positionDifference);
            }
			
			// Update the particles color
			currentParticle->color.r += (currentParticle->deltaColor.r * aDelta);
			currentParticle->color.g += (currentParticle->deltaColor.g * aDelta);
			currentParticle->color.b += (currentParticle->deltaColor.b * aDelta);
			currentParticle->color.a += (currentParticle->deltaColor.a * aDelta);

            GLKVector4 c;

            if (_opacityModifyRGB) {
                c = (GLKVector4){currentParticle->color.r * currentParticle->color.a,
                    currentParticle->color.g * currentParticle->color.a,
                    currentParticle->color.b * currentParticle->color.a,
                    currentParticle->color.a};
            } else {
                c = currentParticle->color;
            }
            
			// Update the particle size
			currentParticle->particleSize += currentParticle->particleSizeDelta * aDelta;
            currentParticle->particleSize = MAX(0, currentParticle->particleSize);

            // Update the rotation of the particle
            currentParticle->rotation += currentParticle->rotationDelta * aDelta;

            // As we are rendering the particles as quads, we need to define 6 vertices for each particle
            GLfloat halfSize = currentParticle->particleSize * 0.5f;

            // If a rotation has been defined for this particle then apply the rotation to the vertices that define
            // the particle
            if (currentParticle->rotation) {
                float x1 = -halfSize;
                float y1 = -halfSize;
                float x2 = halfSize;
                float y2 = halfSize;
                float x = currentParticle->position.x;
                float y = currentParticle->position.y;
                float r = GLKMathDegreesToRadians(currentParticle->rotation);
                float cr = cosf(r);
                float sr = sinf(r);
                float ax = x1 * cr - y1 * sr + x;
                float ay = x1 * sr + y1 * cr + y;
                float bx = x2 * cr - y1 * sr + x;
                float by = x2 * sr + y1 * cr + y;
                float cx = x2 * cr - y2 * sr + x;
                float cy = x2 * sr + y2 * cr + y;
                float dx = x1 * cr - y2 * sr + x;
                float dy = x1 * sr + y2 * cr + y;
                
                quads[particleIndex].bl.vertex.x = ax;
                quads[particleIndex].bl.vertex.y = ay;
                quads[particleIndex].bl.color = c;
                
                quads[particleIndex].br.vertex.x = bx;
                quads[particleIndex].br.vertex.y = by;
                quads[particleIndex].br.color = c;
                
                quads[particleIndex].tl.vertex.x = dx;
                quads[particleIndex].tl.vertex.y = dy;
                quads[particleIndex].tl.color = c;
                
                quads[particleIndex].tr.vertex.x = cx;
                quads[particleIndex].tr.vertex.y = cy;
                quads[particleIndex].tr.color = c;
            } else {
                // Using the position of the particle, work out the four vertices for the quad that will hold the particle
                // and load those into the quads array.
                quads[particleIndex].bl.vertex.x = currentParticle->position.x - halfSize;
                quads[particleIndex].bl.vertex.y = currentParticle->position.y - halfSize;
                quads[particleIndex].bl.color = c;
                
                quads[particleIndex].br.vertex.x = currentParticle->position.x + halfSize;
                quads[particleIndex].br.vertex.y = currentParticle->position.y - halfSize;
                quads[particleIndex].br.color = c;
                
                quads[particleIndex].tl.vertex.x = currentParticle->position.x - halfSize;
                quads[particleIndex].tl.vertex.y = currentParticle->position.y + halfSize;
                quads[particleIndex].tl.color = c;
                
                quads[particleIndex].tr.vertex.x = currentParticle->position.x + halfSize;
                quads[particleIndex].tr.vertex.y = currentParticle->position.y + halfSize;
                quads[particleIndex].tr.color = c;
//                quads[particleIndex].bl.vertex.x = 250 * 3;
//                quads[particleIndex].bl.vertex.y = 400 * 3;
//                quads[particleIndex].bl.color = c;
//                
//                quads[particleIndex].br.vertex.x = 250 * 3;
//                quads[particleIndex].br.vertex.y = 500 * 3;
//                quads[particleIndex].br.color = c;
//                
//                quads[particleIndex].tl.vertex.x = 350 * 3;
//                quads[particleIndex].tl.vertex.y = 400 * 3;
//                quads[particleIndex].tl.color = c;
//                
//                quads[particleIndex].tr.vertex.x = 350 * 3;
//                quads[particleIndex].tr.vertex.y = 500 * 3;
//                quads[particleIndex].tr.color = c;
            }
//            TextureVector4 textureV;
//            if(self.texturePositions){
//                int curTexIndex = [self.vertexTextIndex[@(particleIndex)] intValue];
//                int rnd = curDuration * 60 / 5;
//                rnd = rnd % 12;
////                rnd = rnd % self.texturePositions.count;
//              //  NSLog(@" rnd %f %d",curDuration, rnd);
//                NSValue *value = [self.texturePositions objectAtIndex:rnd + (curTexIndex * 12)];
//                [value getValue:&textureV];
//                //                    self.vertexTextIndex[@(particleIndex)] = @(rnd);
//            }
            
//            quads[particleIndex].bl.texture.x = textureV.bl.x;
//            quads[particleIndex].bl.texture.y = textureV.bl.y;
//            
//            quads[particleIndex].br.texture.x = textureV.br.x;
//            quads[particleIndex].br.texture.y = textureV.br.y;
//            
//            quads[particleIndex].tl.texture.x = textureV.tl.x;
//            quads[particleIndex].tl.texture.y = textureV.tl.y;
//            
//            quads[particleIndex].tr.texture.x = textureV.tr.x;
//            quads[particleIndex].tr.texture.y = textureV.tr.y;
			// Update the particle and vertex counters
			particleIndex++;
		} else {

			// As the particle is not alive anymore replace it with the last active particle 
			// in the array and reduce the count of particles by one.  This causes all active particles
			// to be packed together at the start of the array so that a particle which has run out of
			// life will only drop into this clause once
			if (particleIndex != particleCount - 1)
				particles[particleIndex] = particles[particleCount - 1];
            
			particleCount--;
		}
	}
}

- (void)stopParticleEmitter {
	active = NO;
	elapsedTime = 0;
	emitCounter = 0;
}

- (void)reset
{
    active = YES;
    elapsedTime = 0;
    for (int i = 0; i < particleCount; i++) {
        Particle *p = &particles[i];
        p->timeToLive = 0;
    }
    emitCounter = 0;
    emissionRate = maxParticles / particleLifespan;
}

- (void)renderParticles {
    glBindFramebuffer(GL_FRAMEBUFFER, self.reusableFramebuffer);
//    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glBlendFunc(blendFuncSource, blendFuncDestination);
    [self.sprogram use];
//    GLuint vertexBuffer;
//    glGenBuffers(1, &vertexBuffer);
//    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
//    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices4), Vertices4, GL_STATIC_DRAW);
//
    glBindBuffer(GL_ARRAY_BUFFER, verticesID);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(ParticleQuad) * particleIndex, quads);
    // Configure the vertex pointer which will use the currently bound VBO for its data
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedColoredVertex), 0);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(TexturedColoredVertex), (GLvoid*) offsetof(TexturedColoredVertex, color));
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedColoredVertex), (GLvoid*) offsetof(TexturedColoredVertex, texture));
//    glActiveTexture(GL_TEXTURE0);
    
//    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
//    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)(sizeof(float) * 3));
//    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)(sizeof(float) * 7));
//    
    glActiveTexture(GL_TEXTURE0);
    //    GLTexture *stextue2 = [[GLTexture alloc] initWithFilename:@"2.jpg"];
    
    glBindTexture(GL_TEXTURE_2D, texture.name);
    glUniform1i([self.sprogram uniformIndex:@"sampler2d"], 0);
    
    glDrawElements(GL_TRIANGLES, particleIndex * 6, GL_UNSIGNED_SHORT, indices);
//    glDrawArrays(GL_TRIANGLES, 0, 4);
    
//    if(!self.reusableFramebuffer){
//        glGenFramebuffers(1, &_reusableFramebuffer);
//    }
//
//    glBindFramebuffer(GL_FRAMEBUFFER, _reusableFramebuffer);
//    GLTexture *stextue2 = [[GLTexture alloc] initWithFilename:self.textureFile];
//    FGLKProgram *sprogram = [[FGLKProgram alloc] initWithVertexShaderName:@"mask" fragmentShaderName:@"mask"];
//    [sprogram bindAttributes:@{@(0):@"inPosition",@(1):@"inColor",@(2):@"inTexcoord"}];
//    [sprogram link];
//    [sprogram use];
//
//    glClear(GL_COLOR_BUFFER_BIT);
    
//    shaderEffect.texture2d0.name = texture.name;
//    shaderEffect.texture2d0.enabled = YES;
//    
//    [shaderEffect prepareToDraw];
    
//	// Bind to the verticesID VBO and popuate it with the necessary vertex, color and texture informaiton
//	glBindBuffer(GL_ARRAY_BUFFER, verticesID);
//    
//    // Using glBufferSubData means that a copy is done from the quads array to the buffer rather than recreating the buffer which
//    // would be an allocation and copy. The copy also only takes over the number of live particles. This provides a nice performance
//    // boost.
//    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(ParticleQuad) * particleIndex, quads);
//    
////    glEnableVertexAttribArray(GLKVertexAttribPosition);
////    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
////    glEnableVertexAttribArray(GLKVertexAttribColor);
//
//	// Configure the vertex pointer which will use the currently bound VBO for its data
//    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedColoredVertex), 0);
//    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(TexturedColoredVertex), (GLvoid*) offsetof(TexturedColoredVertex, color));
//    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedColoredVertex), (GLvoid*) offsetof(TexturedColoredVertex, texture));
//    glActiveTexture(GL_TEXTURE0);
//    
//    [stextue2 use];
//    glUniform1i([sprogram uniformIndex:@"maskTexture"], 0);
//    
//    glActiveTexture(GL_TEXTURE1);
//    [stextue2 use];
//    glUniform1i([sprogram uniformIndex:@"texture"], 1);
    // Set the blend function based on the configuration
//    glBlendFunc(blendFuncSource, blendFuncDestination);
    
	// Now that all of the VBOs have been used to configure the vertices, pointer size and color
	// use glDrawArrays to draw the points
//    glDrawElements(GL_TRIANGLES, particleIndex * 6, GL_UNSIGNED_SHORT, indices);
//
//	// Unbind the current VBO
	glBindBuffer(GL_ARRAY_BUFFER, 0);
//
}

@end

#pragma mark -
#pragma mark Private implementation

@implementation ParticleEmitter (Private)

- (BOOL)addParticle {
	
	// If we have already reached the maximum number of particles then do nothing
	if (particleCount == maxParticles)
		return NO;
	
	// Take the next particle out of the particle pool we have created and initialize it
	Particle *particle = &particles[particleCount];
	[self initParticle:particle];
	
	// Increment the particle count
	particleCount++;
	
	// Return YES to show that a particle has been created
	return YES;
}

- (void)initParticle:(Particle*)particle {
	
	// Init the position of the particle.  This is based on the source position of the particle emitter
	// plus a configured variance.  The RANDOM_MINUS_1_TO_1 macro allows the number to be both positive
	// and negative
	particle->position.x = sourcePosition.x + sourcePositionVariance.x * RANDOM_MINUS_1_TO_1;
	particle->position.y = sourcePosition.y + sourcePositionVariance.y * RANDOM_MINUS_1_TO_1;
    particle->startPos.x = sourcePosition.x;
    particle->startPos.y = sourcePosition.y;
	
	// Init the direction of the particle.  The newAngle is calculated using the angle passed in and the
	// angle variance.
	GLfloat newAngle = GLKMathDegreesToRadians(angle + angleVariance * RANDOM_MINUS_1_TO_1);
	
	// Create a new GLKVector2 using the newAngle
	GLKVector2 vector = GLKVector2Make(cosf(newAngle), sinf(newAngle));
	
	// Calculate the vectorSpeed using the speed and speedVariance which has been passed in
	GLfloat vectorSpeed = speed + speedVariance * RANDOM_MINUS_1_TO_1;
	
	// The particles direction vector is calculated by taking the vector calculated above and
	// multiplying that by the speed
	particle->direction = GLKVector2MultiplyScalar(vector, vectorSpeed);
	
    // Calculate the particles life span using the life span and variance passed in
	particle->timeToLive = MAX(0, particleLifespan + particleLifespanVariance * RANDOM_MINUS_1_TO_1);
    
    float startRadius = maxRadius + maxRadiusVariance * RANDOM_MINUS_1_TO_1;
    float endRadius = minRadius + minRadiusVariance * RANDOM_MINUS_1_TO_1;
    
	// Set the default diameter of the particle from the source position
	particle->radius = startRadius;
	particle->radiusDelta = (endRadius - startRadius) / particle->timeToLive;
	particle->angle = GLKMathDegreesToRadians(angle + angleVariance * RANDOM_MINUS_1_TO_1);
	particle->degreesPerSecond = GLKMathDegreesToRadians(rotatePerSecond + rotatePerSecondVariance * RANDOM_MINUS_1_TO_1);
    
    particle->radialAcceleration = radialAcceleration + radialAccelVariance * RANDOM_MINUS_1_TO_1;
    particle->tangentialAcceleration = tangentialAcceleration + tangentialAccelVariance * RANDOM_MINUS_1_TO_1;
	
	// Calculate the particle size using the start and finish particle sizes
	GLfloat particleStartSize = startParticleSize + startParticleSizeVariance * RANDOM_MINUS_1_TO_1;
	GLfloat particleFinishSize = finishParticleSize + finishParticleSizeVariance * RANDOM_MINUS_1_TO_1;
	particle->particleSizeDelta = ((particleFinishSize - particleStartSize) / particle->timeToLive);
	particle->particleSize = MAX(0, particleStartSize);
	
	// Calculate the color the particle should have when it starts its life.  All the elements
	// of the start color passed in along with the variance are used to calculate the star color
	GLKVector4 start = {0, 0, 0, 0};
	start.r = startColor.r + startColorVariance.r * RANDOM_MINUS_1_TO_1;
	start.g = startColor.g + startColorVariance.g * RANDOM_MINUS_1_TO_1;
	start.b = startColor.b + startColorVariance.b * RANDOM_MINUS_1_TO_1;
	start.a = startColor.a + startColorVariance.a * RANDOM_MINUS_1_TO_1;
	
	// Calculate the color the particle should be when its life is over.  This is done the same
	// way as the start color above
	GLKVector4 end = {0, 0, 0, 0};
	end.r = finishColor.r + finishColorVariance.r * RANDOM_MINUS_1_TO_1;
	end.g = finishColor.g + finishColorVariance.g * RANDOM_MINUS_1_TO_1;
	end.b = finishColor.b + finishColorVariance.b * RANDOM_MINUS_1_TO_1;
	end.a = finishColor.a + finishColorVariance.a * RANDOM_MINUS_1_TO_1;
	
	// Calculate the delta which is to be applied to the particles color during each cycle of its
	// life.  The delta calculation uses the life span of the particle to make sure that the
	// particles color will transition from the start to end color during its life time.  As the game
	// loop is using a fixed delta value we can calculate the delta color once saving cycles in the
	// update method
	
    particle->color = start;
	particle->deltaColor.r = ((end.r - start.r) / particle->timeToLive);
	particle->deltaColor.g = ((end.g - start.g) / particle->timeToLive);
	particle->deltaColor.b = ((end.b - start.b) / particle->timeToLive);
	particle->deltaColor.a = ((end.a - start.a) / particle->timeToLive);
    
    // Calculate the rotation
    GLfloat startA = rotationStart + rotationStartVariance * RANDOM_MINUS_1_TO_1;
    GLfloat endA = rotationEnd + rotationEndVariance * RANDOM_MINUS_1_TO_1;
    particle->rotation = startA;
    particle->rotationDelta = (endA - startA) / particle->timeToLive;
    
}

- (void)parseParticleConfig:(TBXML*)aConfig {

	TBXMLElement *rootXMLElement = aConfig.rootXMLElement;
	
	// Make sure we have a root element or we cant process this file
    NSAssert(rootXMLElement, @"ERROR - ParticleEmitter: Could not find root element in particle config file.");
	
	
	// Load all of the values from the XML file into the particle emitter.  The functions below are using the
	// TBXMLAdditions category.  This adds convenience methods to TBXML to help cut down on the code in this method.
    emitterType                 = [aConfig intValueFromChildElementNamed:@"emitterType" parentElement:rootXMLElement];
	sourcePosition              = [aConfig glkVector2FromChildElementNamed:@"sourcePosition" parentElement:rootXMLElement];
	sourcePositionVariance      = [aConfig glkVector2FromChildElementNamed:@"sourcePositionVariance" parentElement:rootXMLElement];
	speed                       = [aConfig floatValueFromChildElementNamed:@"speed" parentElement:rootXMLElement];
	speedVariance               = [aConfig floatValueFromChildElementNamed:@"speedVariance" parentElement:rootXMLElement];
	particleLifespan            = [aConfig floatValueFromChildElementNamed:@"particleLifeSpan" parentElement:rootXMLElement];
	particleLifespanVariance    = [aConfig floatValueFromChildElementNamed:@"particleLifespanVariance" parentElement:rootXMLElement];
	angle                       = [aConfig floatValueFromChildElementNamed:@"angle" parentElement:rootXMLElement];
	angleVariance               = [aConfig floatValueFromChildElementNamed:@"angleVariance" parentElement:rootXMLElement];
	gravity                     = [aConfig glkVector2FromChildElementNamed:@"gravity" parentElement:rootXMLElement];
    radialAcceleration          = [aConfig floatValueFromChildElementNamed:@"radialAcceleration" parentElement:rootXMLElement];
    tangentialAcceleration      = [aConfig floatValueFromChildElementNamed:@"tangentialAcceleration" parentElement:rootXMLElement];
    tangentialAccelVariance     = [aConfig floatValueFromChildElementNamed:@"tangentialAccelVariance" parentElement:rootXMLElement];
	startColor                  = [aConfig glkVector4FromChildElementNamed:@"startColor" parentElement:rootXMLElement];
	startColorVariance          = [aConfig glkVector4FromChildElementNamed:@"startColorVariance" parentElement:rootXMLElement];
	finishColor                 = [aConfig glkVector4FromChildElementNamed:@"finishColor" parentElement:rootXMLElement];
	finishColorVariance         = [aConfig glkVector4FromChildElementNamed:@"finishColorVariance" parentElement:rootXMLElement];
	maxParticles                = [aConfig floatValueFromChildElementNamed:@"maxParticles" parentElement:rootXMLElement];
	startParticleSize           = [aConfig floatValueFromChildElementNamed:@"startParticleSize" parentElement:rootXMLElement] * [UIScreen mainScreen].scale;
	startParticleSizeVariance   = [aConfig floatValueFromChildElementNamed:@"startParticleSizeVariance" parentElement:rootXMLElement] * [UIScreen mainScreen].scale;
	finishParticleSize          = [aConfig floatValueFromChildElementNamed:@"finishParticleSize" parentElement:rootXMLElement] * [UIScreen mainScreen].scale;
	finishParticleSizeVariance  = [aConfig floatValueFromChildElementNamed:@"finishParticleSizeVariance" parentElement:rootXMLElement] * [UIScreen mainScreen].scale;
	duration                    = [aConfig floatValueFromChildElementNamed:@"duration" parentElement:rootXMLElement];
	blendFuncSource             = [aConfig intValueFromChildElementNamed:@"blendFuncSource" parentElement:rootXMLElement];
    blendFuncDestination        = [aConfig intValueFromChildElementNamed:@"blendFuncDestination" parentElement:rootXMLElement];
	
	// These paramters are used when you want to have the particles spinning around the source location
	maxRadius                   = [aConfig floatValueFromChildElementNamed:@"maxRadius" parentElement:rootXMLElement];
	maxRadiusVariance           = [aConfig floatValueFromChildElementNamed:@"maxRadiusVariance" parentElement:rootXMLElement];
	minRadius                   = [aConfig floatValueFromChildElementNamed:@"minRadius" parentElement:rootXMLElement];
	minRadiusVariance           = [aConfig floatValueFromChildElementNamed:@"minRadiusVariance" parentElement:rootXMLElement];
	rotatePerSecond             = [aConfig floatValueFromChildElementNamed:@"rotatePerSecond" parentElement:rootXMLElement];
	rotatePerSecondVariance     = [aConfig floatValueFromChildElementNamed:@"rotatePerSecondVariance" parentElement:rootXMLElement];
    rotationStart               = [aConfig floatValueFromChildElementNamed:@"rotationStart" parentElement:rootXMLElement];
    rotationStartVariance       = [aConfig floatValueFromChildElementNamed:@"rotationStartVariance" parentElement:rootXMLElement];
    rotationEnd                 = [aConfig floatValueFromChildElementNamed:@"rotationEnd" parentElement:rootXMLElement];
    rotationEndVariance         = [aConfig floatValueFromChildElementNamed:@"rotationEndVariance" parentElement:rootXMLElement];
	
	// Calculate the emission rate
	emissionRate                = maxParticles / particleLifespan;
    emitCounter                 = 0;
    
    
	// First thing to grab is the texture that is to be used for the point sprite
	TBXMLElement *element = [TBXML childElementNamed:@"texture" parentElement:rootXMLElement];
	if (element) {
		NSString *fileName = [TBXML valueOfAttributeNamed:@"name" forElement:element];
        NSString *fileData = [TBXML valueOfAttributeNamed:@"data" forElement:element];
        
        NSData *tiffData = nil;
        NSError *error;
        
        if(self.textureFile){
            NSString* fileName = [[self.textureFile lastPathComponent] stringByDeletingPathExtension];
            NSString* extension = [self.textureFile pathExtension];
            NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:extension];
            NSAssert1(path, @"Unable to find texture file: %@", path);
            tiffData = [[NSData alloc] initWithContentsOfFile:path options:NSDataReadingUncached error:&error];
            NSAssert(!error, @"Unable to load texture");
        }else if (fileName && !fileData.length) {
            // Get path to resource
            NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
            
            // If no path is passed back then something is wrong
            NSAssert1(path, @"Unable to find texture file: %@", path);
            
			// Create a new texture which is going to be used as the texture for the point sprites. As there is
            // no texture data in the file, this is done using an external image file
			tiffData = [[NSData alloc] initWithContentsOfFile:path options:NSDataReadingUncached error:&error];
            
            // Throw assersion error if loading texture failed
            NSAssert(!error, @"Unable to load texture");
		}
        
        // If texture data is present in the file then create the texture image from that data rather than an external file
        else if (fileData.length) {
            // Decode compressed tiff data
            tiffData = [[[NSData alloc] initWithBase64EncodedString:fileData] gzipInflate];
        }
        
        // Create a UIImage from the tiff data to extract colorspace and alpha info
        UIImage *image = [UIImage imageWithData:tiffData];
        CGImageAlphaInfo info = CGImageGetAlphaInfo(image.CGImage);
        CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
        
        // Detect if the image contains alpha data
        BOOL hasAlpha = ((info == kCGImageAlphaPremultipliedLast) ||
                         (info == kCGImageAlphaPremultipliedFirst) ||
                         (info == kCGImageAlphaLast) ||
                         (info == kCGImageAlphaFirst) ? YES : NO);
        
        // Detect if alpha data is premultiplied
        BOOL premultiplied = colorSpace && hasAlpha;
        
        // Is opacity modification required
        _opacityModifyRGB = NO;
        if (blendFuncSource == GL_ONE && blendFuncDestination == GL_ONE_MINUS_SRC_ALPHA) {
            if (premultiplied)
                _opacityModifyRGB = YES;
            else {
                blendFuncSource = GL_SRC_ALPHA;
                blendFuncDestination = GL_ONE_MINUS_SRC_ALPHA;
            }
        }
        
        // Set up options for GLKTextureLoader
        NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @(YES), GLKTextureLoaderOriginBottomLeft,
                                  @(premultiplied), GLKTextureLoaderApplyPremultiplication,
                                  nil];
        
        // Use GLKTextureLoader to load the tiff data into a texture
        texture = [GLKTextureLoader textureWithContentsOfData:tiffData options:options error:&error];
        
        // Throw assersion error if loading texture failed
        NSAssert(!error, @"Unable to load texture");
	}

    FGLKProgram *sprogram = [[FGLKProgram alloc] initWithVertexShaderName:@"spirit" fragmentShaderName:@"spirit"];
    if(self.curBrush[@"v"]){
         sprogram = [[FGLKProgram alloc] initWithVertexShaderName:self.curBrush[@"v"]  fragmentShaderName:self.curBrush[@"f"]];
    }
    [sprogram bindAttributes:@{@(0):@"inPosition",@(1):@"inColor",@(2):@"inTexcoord"}];
    [sprogram link];
    [sprogram use];
    self.sprogram = sprogram;
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, SCREEN_WIDTH * [UIScreen mainScreen].scale, 0, SCREEN_HEIGHT * [UIScreen mainScreen].scale, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    glUniformMatrix4fv([sprogram uniformIndex:@"MVP"], 1, GL_FALSE, MVPMatrix.m);
    
}

- (void)setupArrays {
	// Allocate the memory necessary for the particle emitter arrays
	particles = malloc( sizeof(Particle) * maxParticles );
    quads = calloc(sizeof(ParticleQuad), maxParticles);
    indices = calloc(sizeof(GLushort), maxParticles * 6);
    self.vertexTextIndex = [NSMutableDictionary new];
    // Set up the indices for all particles. This provides an array of indices into the quads array that is used during 
    // rendering. As we are rendering quads there are six indices for each particle as each particle is made of two triangles
    // that are each defined by three vertices.
    for( int i=0;i< maxParticles;i++) {
		indices[i*6+0] = i*4+0;
		indices[i*6+1] = i*4+1;
		indices[i*6+2] = i*4+2;
		
		indices[i*6+5] = i*4+2;
		indices[i*6+4] = i*4+3;
		indices[i*6+3] = i*4+1;
	}
	
    // Set up texture coordinates for all particles as these will not change.
    TextureVector4 textureV;
    if(!self.texturePositions){
        TextureVector4 item = {{0.,0.},{1.,0.},{0.,1.},{1.,1.}};
        NSValue *value = [NSValue value:&item withObjCType:@encode(TextureVector4)];
        [value getValue:&textureV];
    }else{
        int rnd = RandomUIntBelow((int)[self.texturePositions count]);
        NSValue *value = [self.texturePositions objectAtIndex:rnd];
        [value getValue:&textureV];
    }
    for(int i=0; i<maxParticles; i++) {
        if(self.texturePositions){
            int rnd = RandomUIntBelow((int)[self.texturePositions count]);
            NSValue *value = [self.texturePositions objectAtIndex:rnd];
            [value getValue:&textureV];
            self.vertexTextIndex[@(i)] = @(rnd);
        }
        
        quads[i].bl.texture.x = textureV.bl.x;
        quads[i].bl.texture.y = textureV.bl.y;
        
        quads[i].br.texture.x = textureV.br.x;
        quads[i].br.texture.y = textureV.br.y;
        
        quads[i].tl.texture.x = textureV.tl.x;
        quads[i].tl.texture.y = textureV.tl.y;
        
        quads[i].tr.texture.x = textureV.tr.x;
        quads[i].tr.texture.y = textureV.tr.y;
    }
    
	// If one of the arrays cannot be allocated throw an assertion as this is bad
	NSAssert(particles && quads, @"ERROR - ParticleEmitter: Could not allocate arrays.");
    
	// Generate the vertices VBO
	glGenBuffers(1, &verticesID);
    glBindBuffer(GL_ARRAY_BUFFER, verticesID);
    glBufferData(GL_ARRAY_BUFFER, sizeof(ParticleQuad) * maxParticles, quads, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
	// By default the particle emitter is active when created
	active = YES;
	
	// Set the particle count to zero
	particleCount = 0;
	
	// Reset the elapsed time
	elapsedTime = 0;	
}

@end

