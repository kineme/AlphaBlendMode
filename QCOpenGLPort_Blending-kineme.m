//
//  QCOpenGLPort_Blending.m
//  GLTools
//
//  Created by Christopher Wright on 10/8/08.
//  Copyright 2008 Kosada Incorporated. All rights reserved.
//

#import <OpenGL/CGLMacro.h>
#import "SkankySDK/SkankySDK.h"
#import "AlphaBlendModePrincipal.h"

#import <objc/runtime.h>
#import <objc/message.h>

static ptrdiff_t _index;
static ptrdiff_t _enabled;
static ptrdiff_t _testingEnabled;	// 10.6 only
static ptrdiff_t _sourceFunction;
static ptrdiff_t _destFunction;
static ptrdiff_t _alphaFunc;		// 10.6 only
static ptrdiff_t _alphaRef;			// 10.6 only
static Class blendingSuperclass;

static id enhancedBlendingInitWithNodeArguments(id self, SEL sel, id fp8, id fp12)
{
	struct objc_super super = {self, blendingSuperclass};
	self = objc_msgSendSuper(&super, sel, fp8, [self _argumentsFromAttributesKey:@"_blendingPortAttributes" originalArguments:fp12]);
	if(self)
		[self setMaxIndexValue: 3];	// 2 by default, plus each additional mode added in attributes
	return self;	
}

static id enhancedBlendingInitWithNodeArgumentsSL(id self, SEL sel, id fp8, id fp12)
{
	struct objc_super super = {self, blendingSuperclass};
	self = objc_msgSendSuper(&super, sel, fp8, [self _argumentsFromAttributesKey:@"_blendingPortAttributes" originalArguments:fp12]);
	if(self)
	{
		[self setMaxIndexValue: 3];	// 2 by default, plus each additional mode added in attributes
		[self _setFlags:0x4];	// no idea what this does, but if we don't set it, blending is broken
	}
	return self;	
}

static NSDictionary *enhancedBlendingAttributes(id self, SEL sel, id node, id args)
{
	struct objc_super super = {self, blendingSuperclass};
	
	NSMutableDictionary *attributes = [objc_msgSendSuper(&super, sel) mutableCopy];
	
	NSMutableArray *menu = [[attributes objectForKey:@"menu"] mutableCopy];
	if(![menu containsObject: @"Alpha"])
		[menu addObject: @"Alpha"];
	[attributes setObject:menu forKey:@"menu"];
	[menu release];
	
	return [attributes autorelease];
}

static void enhancedBlendingSetOnOpenGLContext(id self, SEL sel, QCOpenGLContext *context)
{		
	unsigned int mode = ((unsigned int*)((unsigned char*)self+_index))[0];//[self indexValue];
	if(mode)
	{
		CGLContextObj cgl_ctx = [[context openGLContext] CGLContextObj];

		GLint sfunc, dfunc;

		glGetIntegerv(GL_BLEND_SRC, (GLint*)((unsigned char*)self+_sourceFunction));
		glGetIntegerv(GL_BLEND_DST, (GLint*)((unsigned char*)self+_destFunction));

		if(! (*((unsigned char*)self+_enabled) = glIsEnabled(GL_BLEND)) )
			glEnable(GL_BLEND);
		switch(mode)
		{
			case 1:	// over
				sfunc = GL_ONE;
				dfunc = GL_ONE_MINUS_SRC_ALPHA;
				break;
			case 2:	// add
				sfunc = dfunc = GL_ONE;
				break;
			case 3:	// Alpha!
				sfunc = GL_SRC_ALPHA;
				dfunc = GL_ONE_MINUS_SRC_ALPHA;
		}
		// save an unnecessary state transition if things haven't changed
		if(sfunc != *(GLint*)((unsigned char*)self+_sourceFunction) ||
		   dfunc != *(GLint*)((unsigned char*)self+_destFunction))
			glBlendFunc(sfunc, dfunc);
	}
}

static void enhancedBlendingUnsetOnOpenGLContext(id self, SEL sel, QCOpenGLContext *context)
{
	CGLContextObj cgl_ctx = [[context openGLContext] CGLContextObj];
	if(!*((unsigned char*)self+_enabled))
		glDisable(GL_BLEND);
	else
		glBlendFunc(*(GLint*)((unsigned char*)self+_sourceFunction), 
					*(GLint*)((unsigned char*)self+_destFunction));
}

static void enhancedBlendingSetOnOpenGLContextSL(id self, SEL sel, QCOpenGLContext *context)
{
	unsigned int mode = ((unsigned int*)((unsigned char*)self+_index))[0];//[self indexValue];
	if(mode)
	{
		// we diverge from QC here -- we don't get the context if we don't change anything
		// (apple gets it unconditionally, costing 2 useless message sends per port when in Replace blend mode)
		CGLContextObj cgl_ctx = [[context openGLContext] CGLContextObj];

		GLint *_sFunc = (GLint*)((unsigned char*)self+_sourceFunction);
		GLint *_dFunc = (GLint*)((unsigned char*)self+_destFunction);
		
		if(! (*((unsigned char*)self+_enabled) = glIsEnabled(GL_BLEND)) )
			glEnable(GL_BLEND);
		glGetIntegerv(GL_BLEND_SRC, _sFunc);
		glGetIntegerv(GL_BLEND_DST, _dFunc);
		
		GLint sfunc, dfunc;
		switch(mode)
		{
			case 1:	// over
				sfunc = GL_ONE;
				dfunc = GL_ONE_MINUS_SRC_ALPHA;
				break;
			case 2:	// add
				sfunc = dfunc = GL_ONE;
				break;
			case 3:	// Alpha!
				sfunc = GL_SRC_ALPHA;
				dfunc = GL_ONE_MINUS_SRC_ALPHA;
		}
		
		if(sfunc != *_sFunc || dfunc != *_dFunc)
			glBlendFunc(sfunc, dfunc);
		
		if(! (*((unsigned char*)self+_testingEnabled) = glIsEnabled(GL_ALPHA_TEST)) )
			glEnable(GL_ALPHA_TEST);
		glGetIntegerv(GL_ALPHA_TEST_FUNC, (GLint*)((unsigned char*)self+_alphaFunc));
		// we diverge from QC here, because we use GL_ALPHA_TEST_REF, instead of _FUNC
		// (probably a bugfix)  (they fixed this in 10.6.2, finally)
		glGetFloatv(GL_ALPHA_TEST_REF, (GLfloat*)((unsigned char*)self+_alphaRef));
		glAlphaFunc(GL_GREATER, 0.01f);
	}
}

static void enhancedBlendingUnsetOnOpenGLContextSL(id self, SEL sel, QCOpenGLContext *context)
{
	// 2 diversions:  we don't send indexValue to super, and we get the context inside the block
	if( ((unsigned int*)((unsigned char*)self+_index))[0] )
	{
		CGLContextObj cgl_ctx = [[context openGLContext] CGLContextObj];
		
		glBlendFunc(((unsigned int*)((unsigned char*)self+_sourceFunction))[0],
					((unsigned int*)((unsigned char*)self+_destFunction))[0]);
		if(!*((unsigned char*)self+_enabled))
			glDisable(GL_BLEND);
		
		glAlphaFunc(((unsigned int*)((unsigned char*)self+_alphaFunc))[0], 
					((float*)((unsigned char*)self+_alphaRef))[0]);
		
		if(!*((unsigned char*)self+_testingEnabled))
			glDisable(GL_ALPHA_TEST);
	}
}

static void __attribute__ ((constructor)) enhancedBlendingInit()
{
	{
		id self = [AlphaBlendModePrincipal class];
		KIEnsureSystemVersion;
	}

	BOOL onSnowLeopard = NO;
	Class QCOpenGLPort_Blending = objc_getClass("QCOpenGLPort_Blending");
	if(!KIOnLeopard())
	{
		//NSLog(@"on SL");
		onSnowLeopard = YES;
		_testingEnabled = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_testingEnabled"));
		_alphaFunc = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_alphaFunc"));
		_alphaRef = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_alphaRef"));
	}
	
	_index = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_index"));
	_enabled = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_enabled"));
	_sourceFunction = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_sourceFunction"));
	_destFunction = ivar_getOffset(class_getInstanceVariable(QCOpenGLPort_Blending, "_destFunction"));
		
	blendingSuperclass = class_getSuperclass(QCOpenGLPort_Blending);

	// adding a new method -- should check to see if this is already implemented at runtime (it's not in leopard, so we're ok for now)
	class_addMethod(QCOpenGLPort_Blending, @selector(attributes), (IMP)enhancedBlendingAttributes, "@@:");
	if(onSnowLeopard)
	{
		if([QCOpenGLPort_Blending instancesRespondToSelector:@selector(initWithNode:arguments:)])
			method_setImplementation(class_getInstanceMethod(QCOpenGLPort_Blending, @selector(initWithNode:arguments:)),(IMP)enhancedBlendingInitWithNodeArgumentsSL);
		method_setImplementation(class_getInstanceMethod(QCOpenGLPort_Blending, @selector(setOnOpenGLContext:)),(IMP)enhancedBlendingSetOnOpenGLContextSL);
		method_setImplementation(class_getInstanceMethod(QCOpenGLPort_Blending, @selector(unsetOnOpenGLContext:)),(IMP)enhancedBlendingUnsetOnOpenGLContextSL);
	}
	else
	{
		if([QCOpenGLPort_Blending instancesRespondToSelector:@selector(initWithNode:arguments:)])
			method_setImplementation(class_getInstanceMethod(QCOpenGLPort_Blending, @selector(initWithNode:arguments:)),(IMP)enhancedBlendingInitWithNodeArguments);
		method_setImplementation(class_getInstanceMethod(QCOpenGLPort_Blending, @selector(setOnOpenGLContext:)),(IMP)enhancedBlendingSetOnOpenGLContext);
		method_setImplementation(class_getInstanceMethod(QCOpenGLPort_Blending, @selector(unsetOnOpenGLContext:)),(IMP)enhancedBlendingUnsetOnOpenGLContext);
	}
}
