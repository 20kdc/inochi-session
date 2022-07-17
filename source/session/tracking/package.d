/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module session.tracking;
import session.tracking.expr;
import session.tracking.vspace;
import session.scene;
import inochi2d;
import fghj;

public import session.tracking.sources;

/**
    Binding Type
*/
enum BindingType {
    /**
        A binding where the base source is blended via
        in/out ratios
    */
    RatioBinding,

    /**
        A binding in which math expressions are used to
        blend between the sources in the VirtualSpace zone.
    */
    ExpressionBinding,

    /**
        Binding controlled from an external source.
        Eg. over the internet or from a plugin.
    */
    External
}

/**
    Tracking Binding 
*/
class TrackingBinding {
private:
    // Sum of weighted plugin values
    float sum;

    // Combined value of weights
    float weights;

    /**
        Maps an input value to an offset (0.0->1.0)
    */
    float mapValue(float value, float min, float max) {
        float range = max - min;
        float tmp = (value - min);
        float off = tmp / range;
        return clamp(off, 0, 1);
    }

    /**
        Maps an offset (0.0->1.0) to a value
    */
    float unmapValue(float offset, float min, float max) {
        float range = max - min;
        return (range * offset) + min;
    }

public:
    /**
        Display name for the binding
    */
    string name;

    /**
        Display name for the binding (as a C string)
    */
    const(char)* nameCStr;

    /**
        Name of the source blendshape
    */
    string sourceBlendshape;

    /**
        Name of source blendshape (as a C string)
    */
    const(char)* sourceBlendshapeCStr;

    /**
        The type of the binding
    */
    BindingType type;

    /**
        The Inochi2D parameter it should apply to
    */
    Parameter param;

    /**
        Expression (if in ExpressionBinding mode)
    */
    Expression expr;

    /// Ratio for input
    vec2 inRange;

    /// Ratio for output
    vec2 outRange;

    /// Last input value
    float inVal;

    /// Last output value
    float outVal;

    /**
        Weights the user has set for each plugin
    */
    float[string] pluginWeights;

    /**
        The axis to apply the binding to
    */
    int axis;

    /**
        Dampening level
    */
    int dampenLevel;

    /**
        Updates the parameter binding
    */
    void update() {
        param.value.vector[axis] = 0;
        sum = 0;

        switch(type) {
            case BindingType.RatioBinding:
                if (sourceBlendshape.length == 0) break;

                // Calculate the input ratio (within 0->1)
                float src = insScene.space.currentZone.getTrackingFor(sourceBlendshape);
                float target = mapValue(src, inRange.x, inRange.y);

                // NOTE: Dampen level of 0 = no damping
                // Dampen level 1-10 is inverse due to the dampen function taking *speed* as a value.
                if (dampenLevel == 0) inVal = target;
                else inVal = dampen(inVal, target, deltaTime(), cast(float)(11-dampenLevel));
                
                // Calculate the output ratio (whatever outRange is)
                outVal = unmapValue(inVal, outRange.x, outRange.y);   
                param.value.vector[axis] += param.mapAxis(axis, outVal);
                break;

            case BindingType.ExpressionBinding:
                param.value.vector[axis] += expr.call();
                break; 

            // External bindings
            default: break;
        }
    }
    
    /**
        Submit value for late update application
    */
    void submit(string plugin, float value) {
        if (plugin !in pluginWeights)
            pluginWeights[plugin] = 1;
        
        sum += value*pluginWeights[plugin];
        weights += pluginWeights[plugin];
    }

    /**
        Apply all the weighted plugin values
    */
    void lateUpdate() {
        param.value.vector[axis] += round(sum / weights);
    }
}