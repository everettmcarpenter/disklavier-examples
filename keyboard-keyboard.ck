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
1 => int midiDevice;
// mouse
float x;
float y;
// magnitude of randomized note length
float magnitudeOfRandomizedNoteLength;

( 1.0 / 76.0 )::minute => dur beatLength; // length of a beat
float fractions[10]; // fractions of beats
int states[10]; // states (playing on / off)
Event signalOns[10]; // notifiers
Event signalOffs[10]; // notifiers
[ 60, 62, 63, 65, 67, 69, 70, 72, 74 ] @=> int dorian[];

for( int i; i < 127; i++ )
    midout.noteOff( 1, i, 0 );

for( int i; i < 10; i++ )
{    
    spork ~ noteWatch( i, dorian[i % dorian.size()], signalOns[i], signalOffs[i], midout );
    spork ~ signalWatch( i, signalOns[i], signalOffs[i] );
    Math.randomf() + 0.5 => fractions[i];
}

spork ~ mouseShred();

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
            if( msg.which >= 16 && msg.which <= 25 )
            {
                ( ++states[msg.which - 16] % 2 )=> states[msg.which - 16];
                <<< "Note: ", msg.which - 16, " state, ", states[msg.which - 16] >>>;
            }
            else if( msg.which >= 30 && msg.which <= 39 )
            {
                Math.clampf( 0.125 + fractions[msg.which - 30], 0.0125, 8.0 ) => fractions[msg.which - 30];
                <<< "Note: ", msg.which - 30, " duration, ", fractions[msg.which - 30] >>>;
            }
            else if( msg.which >= 44 && msg.which <= 53 )
            {
                Math.clampf( fractions[msg.which - 44] - 0.125, 0.0125, 8.0 ) => fractions[msg.which - 44];
                <<< "Note: ", msg.which - 44, " duration, ", fractions[msg.which - 44] >>>;
            }
        }
    }
}

fun void signalWatch( int id, Event @ signalOn, Event @ signalOff )
{
    while( true )
    {
        0.8 => float bias; // this is note length
        while( states[id] )
        {
            signalOn.broadcast(); // signal note on
            Math.random2f( 0.0, fractions[id] ) * beatLength * magnitudeOfRandomizedNoteLength => dur extra; // calculate randomized offset
            extra + ( beatLength * 0.8 ) * fractions[id] => now; // move in time
            signalOff.broadcast(); // signal note off
            Math.random2f( 0.0, fractions[id] ) * beatLength * magnitudeOfRandomizedNoteLength => extra; // calculate new offset
            extra + ( beatLength * ( 1.0 - bias ) ) * fractions[id] => now; // move in time
        }
        1::ms => now;
    }
}

fun void noteWatch( int id, int midinote, Event @ signalOn, Event @ signalOff, MidiOut @ output )
{
    int extra;
    while( true )
    {
        signalOn => now; // wait around
        MidiMsg midimsg;
        0x90 => midimsg.data1; // note on on channel 1
        if( Math.randomf() < x * x )
            12 => extra;
        else 
            0 => extra;
        midinote + extra => midimsg.data2; // da note
        ( y * 127.0 ) $ int => midimsg.data3; // velocity
        output.send( midimsg ); // send it off!
        <<< "Note On: ", midinote, " at velocity: ", midimsg.data3 >>>;
        signalOff => now; // note length lol
        0x80 => midimsg.data1; // note off on channel 1
        midinote => midimsg.data2; // da note
        ( y * 127.0 ) $ int => midimsg.data3; // velocity
        output.send( midimsg ); // send it off!
        // <<< "Note Off: ", midinote, " at velocity: ", midimsg.data3 >>>;
    }
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
