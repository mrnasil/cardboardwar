shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Noir / Grayscale settings
uniform bool noir_enabled = true;
uniform float contrast : hint_range(0.0, 3.0) = 1.3;
uniform float brightness : hint_range(-1.0, 1.0) = -0.1;

// Old TV / CRT settings
uniform bool crt_enabled = true;
uniform float scanline_count : hint_range(0.0, 1080.0) = 120.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.05;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float aberration_amount : hint_range(0.0, 10.0) = 0.5; // Chromatic aberration

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Chromatic Aberration (Old TV effect) - shifting channels slightly
	vec4 color;
	if (crt_enabled) {
		float output_r = texture(SCREEN_TEXTURE, uv + vec2(aberration_amount * SCREEN_PIXEL_SIZE.x, 0.0)).r;
		float output_g = texture(SCREEN_TEXTURE, uv).g;
		float output_b = texture(SCREEN_TEXTURE, uv - vec2(aberration_amount * SCREEN_PIXEL_SIZE.x, 0.0)).b;
		color = vec4(output_r, output_g, output_b, 1.0);
	} else {
		color = texture(SCREEN_TEXTURE, uv);
	}
	
	// Noir (Grayscale & Contrast)
	if (noir_enabled) {
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		color.rgb = vec3(gray);
		color.rgb = (color.rgb - 0.5) * contrast + 0.5 + brightness;
	}
	
	// Old TV Effects
	if (crt_enabled) {
		// Scanlines
		float scan_speed = 0.05;
		float scanline = sin((uv.y - TIME * scan_speed) * scanline_count * 3.14159 * 2.0);
		color.rgb -= (scanline * scanline_opacity * 0.5); // Darken on scanlines
		
		// Noise/Grain
		float noise = random(uv + vec2(TIME, TIME));
		color.rgb += (noise - 0.5) * noise_amount;
		
		// Vignette
		vec2 center_dist = uv - 0.5;
		float dist = length(center_dist);
		color.rgb *= (1.0 - dist * vignette_intensity);
		
		// Rolling Line (Tracking artifact) - Broken into scratches
		float roll_speed = -0.3; // Slower
		float roll_pos = fract(TIME * roll_speed); 
		float roll_cycle = floor(TIME * roll_speed);
		float show_roll = step(0.6, random(vec2(roll_cycle, 15.0))); // More frequent but subtle
		
		float line_width = 0.002; // Thinner
		float line_intensity = 0.15; 
		
		// Create the vertical line base
		float split_line = smoothstep(line_width, 0.0, abs(uv.x - roll_pos));
		
		// Break it into small segments (scratches/hairs)
		float segment_noise = random(vec2(uv.y * 50.0, TIME * 10.0)); // High frequency Y noise
		float segment_mask = step(0.7, segment_noise); // Only show 30% of the line as segments
		
		color.rgb += vec3(split_line * line_intensity * show_roll * segment_mask);
	}
	
	COLOR = color;
}


