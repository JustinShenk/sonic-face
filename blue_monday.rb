# Monday Blues

# Coded by Sam Aaron
# Edited by Justin Shenk and Richard Sieg

use_debug false
load_samples [:drum_heavy_kick, :drum_snare_soft]
use_bpm (64)

dir = "/Users/justinshenk/Projects/dance/samples"

$settings = sync "/notesend"
$faces = $settings[0]
$mode = $settings[1]
$pan1 = $settings[2]
$pan2 = $settings[3]
$activeColumn = $settings[4]
$pan = (ring -1, -0.5, 0, 0.5, 1).reflect

def listen_to_camera()
  $settings = sync "/notesend"
  $faces = $settings[0]
  $mode = $settings[1]
  $pan1 = $settings[2]
  $pan2 = $settings[3]
  $activeColumn = $settings[4]
end

def get_amp(default, max, threshold)
  return $faces > threshold ? max : default
end

live_loop :time do
  listen_to_camera()
  puts "faces:", $faces
  sleep 2
end

##| with_fx :pitch_shift, window_size: 0.4, time_dis: 0.001 do
live_loop :vocals, delay: 11.5 do
  sample dir + "vocals-1a1.wav", amp: get_amp(0,1,4), rate: 1.01, beat_stretch: 8
  sleep 8
  sample dir + "vocals-1a2.wav", amp: get_amp(0,1,4), rate: 1.01, beat_stretch: 8
  sleep 8
  sample dir + "vocals-1b.wav", amp: get_amp(0,1,4), rate: 1.02, beat_stretch: 16
  sleep 16
  sample dir + "vocals-2a.wav", amp: get_amp(0,1,4), rate: 1.01, beat_stretch: 16
  sleep 15.5
  sample dir + "vocals-2b.wav", amp: get_amp(0,1,4), rate: 1.01, beat_stretch: 16
  sleep 16.8
  puts "I see a ship in the harbor"
  sample dir + "vocals-3a.wav", amp: get_amp(0,1,4), rate: 0.983, beat_stretch: 15
  sleep 15.7
  puts "I thought I was mistaken"
  sample dir + "vocals-3b.wav", amp: get_amp(0,1,4), rate: 0.99, beat_stretch: 15.8
  sleep 16
  ##| end
end

live_loop :drums do
  
  puts "slow drums"
  6.times do
    amp = $faces > 0 ? 1 : 0.2
    sample :drum_heavy_kick, amp: amp, rate: 0.8
    sleep 0.5
  end
  
  puts "fast drums"
  8.times do
    amp = $faces > 0 ? 1 : 0.2
    sample :drum_heavy_kick, amp: amp, rate: 0.8
    sleep 0.125
  end
end

live_loop :clap, delay: 4.5 do
  puts "clap"
  amp = $faces > 1 ? 0.5 : 0
  sample dir + "clap.wav", amp: amp, pan: 0.5, release: 0.01
  sleep 1
end

live_loop :cello, delay: 4 do
  with_fx :reverb, mix: 0.8, room: 0.8 do
    amp = $faces > 2 ? 0.7 : 0.0
    use_synth :blade
    use_transpose -24
    play (ring :F, :E, :D, :D,:G, :C, :D, :D).tick, sustain: 0.55, release: 0.65, amp: amp
    sleep 1
  end
end

live_loop :synths, delay: 12 do
  puts "how does it feel?"
  use_synth :mod_saw
  amp = $faces > 3 ? amp = 0.4 : 0
  use_synth_defaults amp: amp, attack: 0, sustain: 1, release: 0.25, mod_range: 12, mod_phase: 0.5, mod_invert_wave: 1
  notes = (ring :F, :C, :D, :D, :G, :C, :D, :D)
  notes.each do |n|
    tick
    play note(n, octave: 1), cutoff: (line 90, 130, steps: 16).look
    play note(n, octave: 2), cutoff: (line 90, 130, steps: 32).look
    sleep 1
  end
end

live_loop :snare, delay: 12.5 do
  amp = $faces > 2 ? 0.7 : 0.0
  sample :drum_snare_soft, amp: amp
  sleep 1
end
