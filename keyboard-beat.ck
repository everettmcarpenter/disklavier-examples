public class Beat extends Event
{
    dur length;
    int div;
}

4 => int MAX_PHRASE_SIZE;
12 => int RANDOM_INTERVAL;
0.9 => float NOTE_LENGTH; // the higher the number, normalized to [0.0,1.0] ( 1.0 is full beat)

// keyboard
Hid hi;
HidMsg msg;
// keyboard
MidiOut midout;
// mouse
Hid mouse;
HidMsg mmsg;
// device #
0 => int hidDevice;
0 => int midiDevice;
// mouse
float x;
float y;
// this is the magnitude of randomized note length
float magnitudeOfRandomizedNoteLength;
( 1.0 / 98.0 )::minute => dur beatLength; // length of a beat
float fractions[10]; // fractions of beats
int RANDOM_INTERVALS[10];
int BEAT_LENGTHS[10]; 
int states[10]; // states (playing on / off)
Event signalOns[10]; // notifiers
Event signalOffs[10]; // notifiers
Beat beats[4];
[ 60, 62, 63, 65, 67, 69, 70, 72, 74 ] @=> int scale[]; // dorian
// [ 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72 ] @=> int scale[]; // chrome special

// flush
for( int i; i < 127; i++ )
    midout.noteOff( 1, i, 0 );

for( int i; i < 10; i++ )
{    
    spork ~ signalWatch( i % scale.size() );
    Math.randomf() + 0.5 => fractions[i];
}

// listen
spork ~ mouseShred();

// keep time 
for( int i; i < beats.size(); i++ )
    spork ~ beatKeep( beats[i], ( beatLength ) / ( i + 1 ), i + 1 );

// args
if( me.args() == 1 )
    me.arg( 0 ) => Std.atoi => hidDevice;
if( me.args() > 1 )
    me.arg( 1 ) => Std.atoi => midiDevice;

// open keyboard (get device number from command line)
if( !hi.openKeyboard( hidDevice ) ) me.exit();
cherr <= "keyboard '" <= hi.name() <= "' ready" <= "" <= IO.newline();

// open keyboard (get device number from command line)
if( !midout.open( midiDevice ) ) me.exit();
cherr <= "keyboard '" <= midout.name() <= "' ready" <= "" <= IO.newline();

while( true )
{
    hi => now;
    while( hi.recv( msg ) )
    {
        if( msg.isButtonDown() )
        {
            if( msg.which >= 16 && msg.which <= 25 ) // turn on phrase 
            {
                ( ++states[msg.which - 16] % 2 )=> states[msg.which - 16];
                <<< "Note: ", msg.which - 16, " state, ", states[msg.which - 16] >>>;
            }
            else if( msg.which >= 30 && msg.which <= 39 ) // adjust range
            {
                Math.clampi( ++RANDOM_INTERVALS[msg.which - 30], 0, 24 ) => RANDOM_INTERVALS[msg.which - 30];
                <<< "Note: ", msg.which - 30, " range, ", RANDOM_INTERVALS[msg.which - 30] >>>;
            }
            else if( msg.which >= 44 && msg.which <= 53 ) // adjust range
            {
                Math.clampi( --RANDOM_INTERVALS[msg.which - 44], 0, 24 ) => RANDOM_INTERVALS[msg.which - 44];
                <<< "Note: ", msg.which - 44, " range, ", RANDOM_INTERVALS[msg.which - 44] >>>;
            }
            else if( msg.which >= 2 && msg.which <= 11 ) // adjust subdivision
            {
                ++BEAT_LENGTHS[msg.which - 2] % beats.size() => BEAT_LENGTHS[msg.which - 2];
                <<< "Note: ", msg.which - 2, " subdivision, ", beats[BEAT_LENGTHS[msg.which - 2]].div >>>;
            }
            else if( msg.which == 28 )
                for( int i; i < states.size(); i++ )
                    0 => states[i];
            else if( msg.which == 57 )
                cc( 64, 127, midout );
            else if( msg.which == 1 )
                me.exit();
        }
        else if( msg.isButtonUp() )
        {
            if( msg.which == 57 )
                cc( 64, 0, midout );
        }
    }
}

fun void signalWatch( int id )
{
    while( true )
    {
        // length
        Math.random2( 1, MAX_PHRASE_SIZE ) => int phraseLength;
        // 12 => int phraseLength;
        int phrase[phraseLength];
        // always start on the same note
        scale[id] => phrase[0];
        // create it
        for( 1 => int i; i < phraseLength; i++ ) 
            scale[Math.random2( 0, scale.size() - 1 )] => phrase[i];    

        if( states[id] )
        {
            while( states[id] )
            {
                BEAT_LENGTHS[id] => int beatDex;
                beats[beatDex] => now;
                // play back the phrase till we say not to
                for( int i; i < phraseLength; i++ )
                {
                    int shift;
                    if( Math.randomf() > x ) // if x is low, the likelihood that a random process bound between [0,1] is greater than it is a high one
                        Math.random2( -1, 1 ) * RANDOM_INTERVALS[id] => shift; 
                    ( y * 127 ) $ int => int vel; // let's be loud or quiet
                    note( phrase[i] + shift, vel, ( beats[beatDex].length * NOTE_LENGTH ), midout );
                }
            }
        }
        else 
            1::ms => now;
        // now, we've said not to, so we're going to craft a new one
    }
}

fun void note( int note, int velocity, dur length, MidiOut @ output )
{
    // <<< "Note on: ", note >>>;
    noteOn( note, velocity, output );
    length => now;
    noteOff( note, 0, output );
}

fun void cc( int cc, int value, MidiOut @ output )
{
    MidiMsg midimsg;
    0xB0 => midimsg.data1; // note on on channel 1
    cc => midimsg.data2; // da note
    value => midimsg.data3;
    output.send( midimsg ); // send it off!
}

fun void noteOn( int midinote, int velocity, MidiOut @ output )
{
    MidiMsg midimsg;
    0x90 => midimsg.data1; // note on on channel 1
    midinote => midimsg.data2; // da note
    velocity => midimsg.data3;
    output.send( midimsg ); // send it off!
}

fun void noteOff( int midinote, int velocity, MidiOut @ output )
{
    MidiMsg midimsg;
    0x80 => midimsg.data1; // note off on channel 1
    midinote => midimsg.data2; // da note
    velocity => midimsg.data3; // velocity
    output.send( midimsg ); // send it off!
}

fun void mouseShred()
{
	// open mouse 0, exit on fail
	if( !mouse.openMouse( 0 ) ) me.exit();
	<<< "mouse '" + mouse.name() + "' ready", "" >>>;

	while( true )
	{
		mouse => now;
		while( mouse.recv( mmsg ) )
		{
		 	if( mmsg.isMouseMotion() )
		 	{
		 		mmsg.scaledCursorX => x => magnitudeOfRandomizedNoteLength;	
		 		1.0 - mmsg.scaledCursorY => y;	
		 	}
		}
		1024::samp => now; 
	}
}

fun void beatKeep( Beat @ beat, dur rate, int integerDiv )
{
    rate => beat.length;
    integerDiv => beat.div;
    while( true )
    {
        beat.broadcast();
        rate => now;
    }
}