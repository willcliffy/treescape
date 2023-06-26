shader_type spatial;

// Define uniform variables
uniform sampler2D textureVertexInput;
uniform vec4 sourceColor: source_color = vec4(0.000000, 0.266667, 0.533333, 1.000000);
uniform sampler2D textureFragmentInput_1;
uniform sampler2D textureFragmentInput_2;
uniform sampler2D depthTexture : hint_depth_texture;

void vertex() {
    // Time input
    float time = TIME;

    // UV function
    vec2 uvModifier = vec2(0.010000, 0.010000);
    vec2 uv = time * uvModifier + UV;

    // Sample from texture 2D
    vec4 textureSample = texture(textureVertexInput, uv);

    // MultiplyAdd operation
    vec3 vertexOutput = fma(textureSample.xyz, NORMAL, VERTEX);

    // Vertex output
    VERTEX = vertexOutput;
}

void fragment() {
    // Source color
    vec4 color = sourceColor;

    // Time input
    float time_1 = TIME;

    // UV function
    vec2 uvModifier_1 = vec2(0.010000, 0.010000);
    vec2 uv_1 = time_1 * uvModifier_1 + UV;

    // Sample from texture 2D
    vec4 textureSample_1 = texture(textureFragmentInput_1, uv_1);

    // Time input
    float time_2 = TIME;

    // UV function
    vec2 uvModifier_2 = vec2(-0.010000, -0.010000);
    vec2 uv_2 = time_2 * uvModifier_2 + UV;

    // Sample from texture 2D
    vec4 textureSample_2 = texture(textureFragmentInput_2, uv_2);

    // Vector operation
    vec3 textureMultiply = textureSample_1.xyz * textureSample_2.xyz;

    // Float operation
    float powModifier = 1.25000;
    float poweredTexture = pow(textureMultiply.x, powModifier);

    // Vector operation
    vec3 colorOutput = color.xyz + poweredTexture;

    // Time input
    float time_3 = TIME;

    // ProximityFade function
    float proximityModifier = 0.50000;
    float proximityFade;
    {
        float depthTextureSample = texture(depthTexture, SCREEN_UV).r;
        vec4 depthWorldPosition = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depthTextureSample, 1.0);
        depthWorldPosition.xyz /= depthWorldPosition.w;
        proximityFade = clamp(1.0 - smoothstep(depthWorldPosition.z + proximityModifier, depthWorldPosition.z, VERTEX.z), 0.0, 1.0);
    }

    // Float function
    float fadeOutput = 1.0 - proximityFade;

    // MultiplyAdd operation
    float timeFadeModifier = 0.50000;
    float timeFade = fma(time_3, timeFadeModifier, fadeOutput);

    // Float operation
    float timeFadeScale = 4.00000;
    float scaledTimeFade = timeFade * timeFadeScale;

    // Sine operation
    float sineOutput = sin(scaledTimeFade);

    // Absolute operation
    float absoluteSine = abs(sineOutput);

    // Float operation
    float multipliedFade = absoluteSine * fadeOutput;

    // Float operation
    float powModifier_2 = 32.00000;
    float poweredFade = pow(fadeOutput, powModifier_2);

    // Float operation
    float finalFade = multipliedFade + poweredFade;

    // Mix operation
    vec3 mixModifier = vec3(1.00000, 1.00000, 1.00000);
    vec3 finalColor = mix(colorOutput, mixModifier, finalFade);

    // Float constants
    float alphaOutput = 0.800000;
    float roughnessOutput = 0.000000;

    // Output assignments
    ALBEDO = finalColor;
    ALPHA = alphaOutput;
    ROUGHNESS = roughnessOutput;
    EMISSION = vec3(poweredTexture);
}
