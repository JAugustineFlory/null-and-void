shader_type spatial;

// The skinned body (tools/art/build_characters.py): skin, shirt, trousers and
// shoes in one draw. UV.x is the rest height in CharacterRig's units, UV.y how
// far down the arm (0 shoulder, 1 fingertips; 0 off the arms). Vertex colour:
// red darkens the face's detail, green marks the lips, and the eyes carry their
// own colour with alpha 0. SkinnedBody sets the colours and lengths.
uniform vec4 skin_color : source_color = vec4(0.87, 0.68, 0.55, 1.0);
uniform vec4 top_color : source_color = vec4(0.3, 0.4, 0.7, 1.0);
uniform vec4 pants_color : source_color = vec4(0.2, 0.2, 0.25, 1.0);
uniform vec4 shoe_color : source_color = vec4(0.08, 0.07, 0.07, 1.0);
uniform vec4 lip_color : source_color = vec4(0.6, 0.25, 0.3, 1.0);
uniform float lip_amount = 0.0;
uniform float sleeve = 0.33;
uniform float shoe_top = 0.085;
uniform float hem = 0.86;
uniform float neckline = 1.445;
uniform float waist = 0.985;
// Under a jacket the body draws in this far (metres), so it can't poke through
// where the jacket bends with the arms. jacket_hem is where the jacket ends.
uniform float tuck = 0.0;
uniform float jacket_hem = 0.8;
// Your own body in first person, pulled up to an edge or a pipe: what isn't
// arm and is this close to your eyes (the collar, the back of the shoulders) is
// left out, so you see your arms reach past your face (FirstPersonBody). A
// short sleeve goes too: the arm shows from where it comes out of it. The arm
// itself is left out only this much nearer (share of near_cut), where it would
// fill the view; under a jacket, which fades out at near_cut, it goes with it.
uniform float near_cut = 0.0;
const float ARM_NEAR = 0.4;

varying vec2 place;

void vertex() {
	place = vec2(UV.x, 1.0 - UV.y);  // glTF stores V flipped
	if (tuck > 0.0 && place.x > jacket_hem + 0.02 && place.x < neckline - 0.01 && place.y < 0.8) {
		VERTEX -= NORMAL * tuck;
	}
}

void fragment() {
	if (near_cut > 0.0) {
		bool arm = place.y >= (sleeve < 0.5 ? sleeve + 0.03 : 0.12);
		if (length(VERTEX) < (arm && tuck <= 0.0 ? near_cut * ARM_NEAR : near_cut)) {
			discard;
		}
	}
	if (COLOR.a < 0.5) {
		ALBEDO = COLOR.rgb;  // the eyes
		ROUGHNESS = 0.3;
	} else {
		vec3 c = skin_color.rgb;
		float rough = 0.75;
		bool legs = place.y < 0.01;
		if (legs && place.x < shoe_top) {
			c = place.x < 0.012 ? shoe_color.rgb * 0.45 : shoe_color.rgb;  // a darker sole
			rough = 0.7;
		} else if (legs && place.x < waist) {
			c = pants_color.rgb;
			rough = 0.9;
		}
		if (place.x > hem && place.x < neckline && place.y < sleeve) {
			c = top_color.rgb;
			rough = 0.9;
		}
		// Lipstick replaces the lips' own tone; without it they keep a little colour.
		vec3 lips = mix(c * vec3(0.92, 0.72, 0.72), lip_color.rgb, lip_amount);
		c = mix(c, lips, COLOR.g);
		ALBEDO = c * COLOR.r;
		ROUGHNESS = rough;
	}
}
