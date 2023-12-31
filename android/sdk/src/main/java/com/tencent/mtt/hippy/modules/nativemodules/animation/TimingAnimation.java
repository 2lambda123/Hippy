/* Tencent is pleased to support the open source community by making Hippy available.
 * Copyright (C) 2018 THL A29 Limited, a Tencent company. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.tencent.mtt.hippy.modules.nativemodules.animation;

import android.animation.Animator;
import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.os.Build;
import android.text.TextUtils;
import android.view.animation.*;

import java.util.ArrayList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.tencent.mtt.hippy.common.HippyArray;
import com.tencent.mtt.hippy.common.HippyMap;
import com.tencent.mtt.hippy.dom.node.NodeProps;

@SuppressWarnings({"deprecation", "unused"})
public class TimingAnimation extends Animation implements ValueAnimator.AnimatorUpdateListener,
    Animator.AnimatorListener {

  private static final String VALUE_TYPE_RAD = "rad";
  private static final String VALUE_TYPE_DEG = "deg";
  private static final String VALUE_TYPE_COLOR = "color";
  private static final String TIMING_FUNCTION_LINEAR = "linear";
  private static final String TIMING_FUNCTION_EASE_IN = "ease-in";
  private static final String TIMING_FUNCTION_EASE_OUT = "ease-out";
  private static final String TIMING_FUNCTION_EASE_IN_OUT = "ease-in-out";
  private static final String TIMING_FUNCTION_EASE_BEZIER = "ease_bezier";
  private static final Pattern TIMING_FUNCTION_CUBIC_BEZIER_PATTERN = Pattern.compile("^cubic-bezier\\(([^,]*),([^,]*),([^,]*),([^,]*)\\)$");
  protected Number mStartValue = 0;
  protected Number mToValue = 0;
  protected int mDuration;
  protected String mTimingFunction;
  protected final ValueAnimator mAnimator;
  protected String mValueType;
  protected int mRepeatCount = 0;
  protected ValueTransformer mValueTransformer;

  /**
   * Animation delay time
   */
  protected int mDelay = 0;
  private Object mAnimationValue = 0.0;

  public TimingAnimation(int id) {
    super(id);
    mAnimator = new ValueAnimator();
    mAnimator.addUpdateListener(this);
    mAnimator.addListener(this);
  }

  @Override
  public Animator getAnimator() {
    return mAnimator;
  }

  @Override
  public void start() {
    mAnimator.start();
  }

  @Override
  public void stop() {
    mAnimator.cancel();
  }

  @Override
  public Object getAnimationValue() {
    Object simpleValue = getAnimationSimpleValue();
    if ((simpleValue instanceof Number) && mValueTransformer != null) {
      Object transformValue = mValueTransformer.transform((Number) simpleValue);
      if (transformValue != null) {
        simpleValue = transformValue;
      }
    }
    if (TextUtils.equals(mValueType, VALUE_TYPE_RAD)) {
      return simpleValue + "rad";
    } else if (TextUtils.equals(mValueType, VALUE_TYPE_DEG)) {
      return simpleValue + "deg";
    }
    return simpleValue;
  }

  @Override
  public Object getAnimationSimpleValue() {
    return mAnimationValue;
  }

  @Override
  public void resume() {
    if (mAnimator != null) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        mAnimator.resume();
      }
    }
  }

  @Override
  public void pause() {
    if (mAnimator != null) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        mAnimator.pause();
      }
    }
  }

  @Override
  public void onAnimationUpdate(ValueAnimator animation) {
    if (animation != null) {
      mAnimationValue = mAnimator.getAnimatedValue();
    }

    super.onAnimationUpdate(animation);

  }

  public void parseFromData(HippyMap param) {
    if (param.containsKey("valueType")) {
      mValueType = param.getString("valueType");
    }

    if (param.containsKey("delay")) {
      mDelay = param.getInt("delay");
    }

    if (param.containsKey("startValue")) {
      Object value = param.get("startValue");
      mStartValue = value instanceof Number ? (Number) value : 0;
    }
    mAnimationValue = mStartValue;

    if (param.containsKey("toValue")) {
      Object value = param.get("toValue");
      mToValue = value instanceof Number ? (Number) value : 0;
    }

    if (param.containsKey("duration")) {
      mDuration = param.getInt("duration");
    }

    if (param.containsKey("timingFunction")) {
      mTimingFunction = param.getString("timingFunction");
    }

    if (param.containsKey(NodeProps.REPEAT_COUNT)) {
      mRepeatCount = param.getInt(NodeProps.REPEAT_COUNT);
      if (mRepeatCount > 0) {
        mRepeatCount = mRepeatCount - 1;
      }
      mAnimator.setRepeatCount(mRepeatCount);
      mAnimator.setRepeatMode(ValueAnimator.RESTART);
    }

    if (param.containsKey("inputRange")) {
      HippyArray inputRange = param.getArray("inputRange");
      if (param.containsKey("outputRange")) {
        HippyArray outputRange = param.getArray("outputRange");
        mValueTransformer = new ValueTransformer(inputRange, outputRange);
      }
    }

    if (!TextUtils.isEmpty(mValueType) && mValueType.equals(VALUE_TYPE_COLOR)) {
      mAnimator.setIntValues(mStartValue.intValue(), mToValue.intValue());
      mAnimator.setEvaluator(new ArgbEvaluator());
    } else {
      mAnimator.setFloatValues(mStartValue.floatValue(), mToValue.floatValue());
    }

    mAnimator.setDuration(mDuration);
    if (TextUtils.equals(TIMING_FUNCTION_EASE_IN, mTimingFunction)) {
      mAnimator.setInterpolator(new AccelerateInterpolator());
    } else if (TextUtils.equals(TIMING_FUNCTION_EASE_OUT, mTimingFunction)) {
      mAnimator.setInterpolator(new DecelerateInterpolator());
    } else if (TextUtils.equals(TIMING_FUNCTION_EASE_IN_OUT, mTimingFunction)) {
      mAnimator.setInterpolator(new AccelerateDecelerateInterpolator());
    } else if (TextUtils.equals(TIMING_FUNCTION_EASE_BEZIER, mTimingFunction)) {
      this.setCubicBezierInterpolator(0.42f, 0, 1, 1);
    } else {
      Matcher matcher = TIMING_FUNCTION_CUBIC_BEZIER_PATTERN.matcher(mTimingFunction.trim());
      if (matcher.matches()) {
        try {
          this.setCubicBezierInterpolator(
            Float.parseFloat(matcher.group(1)),
            Float.parseFloat(matcher.group(2)),
            Float.parseFloat(matcher.group(3)),
            Float.parseFloat(matcher.group(4))
          );
        } catch (Exception e) {
          mAnimator.setInterpolator(new LinearInterpolator());
        }
      } else {
        mAnimator.setInterpolator(new LinearInterpolator());
      }
    }
    mAnimator.setStartDelay(mDelay);
  }

  private void setCubicBezierInterpolator(float p1x, float p1y, float p2x, float p2y) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      mAnimator.setInterpolator(new PathInterpolator(p1x, p1y, p2x, p2y));
    } else {
      mAnimator.setInterpolator(new BezierInterpolator(p1x, p1y, p2x, p2y));
    }
  }
}
