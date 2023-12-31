/*!
 * iOS SDK
 *
 * Tencent is pleased to support the open source community by making
 * Hippy available.
 *
 * Copyright (C) 2019 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "HippyVirtualNode.h"

@implementation UIView (HippyRemoveNode)
- (void)removeView:(HippyRemoveViewForShadow)removeBlock {
    removeBlock(self.hippyTag);

    for (UIView *view in self.subviews) {
        [view removeView:removeBlock];
    }
}
@end

typedef NS_ENUM(NSUInteger, CreationType) {
    CreationTypeUnknown,
    CreationTypeRealTime,
    CreationTypeAsNeeded,
};

@interface HippyVirtualNode () {
    CreationType _creationType;
}

@end

@implementation HippyVirtualNode

@synthesize viewName = _viewName;
@synthesize hippyTag = _hippyTag;
@synthesize props = _props;
@synthesize frame = _frame;
@synthesize parent = _parent;
@synthesize rootTag = _rootTag;
@synthesize tagName = _tagName;

+ (HippyVirtualNode *)createNode:(NSNumber *)hippyTag viewName:(NSString *)viewName props:(NSDictionary *)props {
    HippyAssertParam(hippyTag);
    HippyAssertParam(viewName);

    HippyVirtualNode *node = [[[self class] alloc] initWithTag:hippyTag viewName:viewName props:props];
    return node;
}

- (instancetype)initWithTag:(NSNumber *)hippyTag viewName:(NSString *)viewName props:(NSDictionary *)props {
    if (self = [super init]) {
        self.hippyTag = hippyTag;
        _viewName = viewName;
        _subNodes = [NSMutableArray array];
        _props = [props copy];
    }
    return self;
}

- (void)hippySetFrame:(CGRect)frame {
    self.frame = frame;
}

- (void)insertHippySubview:(id<HippyComponent>)subview atIndex:(__unused NSInteger)atIndex {
    [self.subNodes insertObject:subview atIndex:atIndex];
}

- (void)removeHippySubview:(id<HippyComponent>)subview {
    [self.subNodes removeObject:subview];
}

- (NSArray<id<HippyComponent>> *)hippySubviews {
    return self.subNodes;
}

- (id<HippyComponent>)hippySuperview {
    return self.parent;
}

- (NSNumber *)hippyTagAtPoint:(__unused CGPoint)point {
    return self.hippyTag;
}

- (BOOL)isHippyRootView {
    return NO;
}

- (BOOL)isList {
    return NO;
}

- (BOOL)isLazilyLoadType {
    return NO;
}

- (BOOL)createViewLazily {
    if (_creationType == CreationTypeUnknown) {
        BOOL createViewLazily = NO;
        HippyVirtualNode *pNode = [self parent];
        while (pNode) {
            if ([pNode createViewLazily]) {
                createViewLazily = YES;
                break;
            }
            else {
                pNode = [pNode parent];
            }
        }
        _creationType = createViewLazily ? CreationTypeAsNeeded : CreationTypeRealTime;
        return createViewLazily;
    }
    else {
        BOOL createViewLazily = (_creationType == CreationTypeAsNeeded);
        return createViewLazily;
    }
}

- (void)setParent:(id<HippyComponent>)parent {
    _parent = parent;
    _creationType = CreationTypeUnknown;
}

- (HippyVirtualNode *)firstLazilyLoadTypeParentNode {
    HippyVirtualNode *node = [self parent];
    BOOL isNodeLazily = [node isLazilyLoadType];
    while (!isNodeLazily && node) {
        node = [node parent];
        isNodeLazily = [node isLazilyLoadType];
    }
    return node;
}

- (UIView *)createView:(HippyCreateViewForShadow)createBlock insertChildrens:(HippyInsertViewForShadow)insertChildrens {
    UIView *containerView = createBlock(self);
    NSMutableArray *childrens = [NSMutableArray new];
    for (HippyVirtualNode *node in self.subNodes) {
        UIView *view = [node createView:createBlock insertChildrens:insertChildrens];
        if (view) {
            [childrens addObject:view];
        }
    }
    insertChildrens(containerView, childrens);
    return containerView;
}

- (void)removeView:(HippyRemoveViewForShadow)removeBlock {
    removeBlock(self.hippyTag);

    for (HippyVirtualNode *child in self.subNodes) {
        [child removeView:removeBlock];
    }
}

- (void)updateView:(HippyUpdateViewForShadow)updateBlock withOldNode:(HippyVirtualNode *)oldNode {
    updateBlock(self, oldNode);

    NSInteger index = 0;
    for (HippyVirtualNode *node in self.subNodes) {
        [node updateView:updateBlock withOldNode:oldNode.subNodes[index++]];
    }
}

- (NSDictionary *)diff:(HippyVirtualNode *)newNode {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    // key: new node tag value: parent tag,
    [result setObject:[NSMutableDictionary dictionary] forKey:@"insert"];
    // old tags
    [result setObject:[NSMutableArray array] forKey:@"remove"];
    // key: new tag, value: old tag
    [result setObject:[NSMutableDictionary dictionary] forKey:@"update"];
    // key: new tag, value: old tag
    [result setObject:[NSMutableDictionary dictionary] forKey:@"tag"];

    if ([self.viewName isEqualToString:newNode.viewName]) {
        if (![self.props isEqualToDictionary:newNode.props]) {
            [result[@"update"] setObject:self.hippyTag forKey:newNode.hippyTag];
        }
    } else {
        return nil;
    }

    [result[@"tag"] setObject:self.hippyTag forKey:newNode.hippyTag];

    [self _diff:newNode withResult:result];

    return result;
}

- (void)_diff:(HippyVirtualNode *)newNode withResult:(NSMutableDictionary *)result {
    for (NSUInteger index = 0; index < MAX(self.subNodes.count, newNode.subNodes.count); index++) {
        HippyVirtualNode *oldSubNode = nil;
        HippyVirtualNode *newSubNode = nil;

        if (index < self.subNodes.count) {
            oldSubNode = self.subNodes[index];
        }
        if (index < newNode.subNodes.count) {
            newSubNode = newNode.subNodes[index];
        }

        if (oldSubNode == nil && newSubNode) {  // 需要插入新的节点
            NSMutableDictionary *insertDict = result[@"insert"];
            [insertDict setObject:@{ @"index": @(index), @"tag": self.hippyTag } forKey:newSubNode.hippyTag];
        } else if (oldSubNode && newSubNode == nil) {  // 需要移除老节点
            NSMutableArray *remove = result[@"remove"];
            [remove addObject:oldSubNode.hippyTag];
        } else if (oldSubNode && newSubNode) {
            if (![oldSubNode.viewName isEqualToString:newSubNode.viewName]) {  // 需要插入新节点和移除老节点
                NSMutableDictionary *insertDict = result[@"insert"];
                [insertDict setObject:@{ @"index": @(index), @"tag": self.hippyTag } forKey:newSubNode.hippyTag];

                NSMutableArray *remove = result[@"remove"];
                [remove addObject:oldSubNode.hippyTag];
            } else {
                if (![oldSubNode.props isEqualToDictionary:newSubNode.props]) {  // 需要更新节点并且继续比较子节点
                    NSMutableDictionary *updateDict = result[@"update"];
                    [updateDict setObject:oldSubNode.hippyTag forKey:newSubNode.hippyTag];
                }
                [oldSubNode _diff:newSubNode withResult:result];

                NSMutableDictionary *tagDict = result[@"tag"];
                [tagDict setObject:oldSubNode.hippyTag forKey:newSubNode.hippyTag];
            }
        } else {
            assert(0);
        }
    }
}

@end
