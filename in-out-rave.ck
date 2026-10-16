// awesome synth voice
class Voice extends Chugraph
{
    Blit blt => Gain voicedVolume( 0.8 ) => Gain sum( 0.05 ) => Envelope env( 1::second ) => outlet;
    Noise noise => Gain unvoicedVolume( 1.0 - voicedVolume.gain() );

    fun dur noteState( int note )
    {
        blt.freq( Math.mtof( note ) );
        blt.harmonics( Math.random2( 0, 3 ) );
        env.keyOn();
        return env.duration();
    }

    fun dur noteOff()
    {
        env.keyOff();
        return env.duration();
    }
    
    fun void duration( dur length )
    { env.duration( length ); }

    fun dur duration() 
    { return env.duration(); }

    fun void timbre( float mix ) // 1.0 tonal, 0.0 noise
    { voicedVolume.gain( mix ); unvoicedVolume.gain( 1.0 - mix ); }
}

// input midi device
0 => int inmidi;
// output midi device
0 => int outmidi; 

// check for some arguments
if( me.args() == 2 )
{
    me.arg( 0 ) => Std.atoi => inmidi;
    me.arg( 1 ) => Std.atoi => outmidi;
}
else 
    chout <= "No arguments given, assuming input and output midi devices are 0" <= IO.nl();

// we'll need to listen for midi input
MidiIn midin;
// and send midi output
MidiOut midout;
// 
Event pressed[127];
Event released[127];
//
time timePressed[127]; // last time this note was pressed
time timeReleased[127]; // last time this note was released
//
int pressedVelocity[127]; // note on velocity

// waveguides
Voice blt;

// notes that are actively on, whether through human input or computer
int noteState[127];
// synths that are on
int synthState[127];

// color array
vec3 colors[127];

// pool size
int size;

// open the device
if( !midin.open( inmidi ) ) 
    me.exit();

// open the device
if( !midout.open( outmidi ) ) 
    me.exit();

// listen to me!
spork ~ in();

// wait
while( true )
{
    // time zones
    10::ms => now;
}

fun void in()
{
    // last msg
    time timeOfLast; // oh boy now we have memory
    // state of pedal
    int pedalState;
    // the iconic infinite time loop
    while( true )
    {
        // listen for our input
        midin => now;
        // let's store the input in here and read it
        MidiMsg msg;
        // read it
        while( midin.recv( msg ) )
        {
            // if note on ( this is for channel 1 (0) )
            if( msg.data1 == 0x90 )
            {
                // this is the note
                msg.data2 => int note;
                // this is the velocity
                msg.data3 => int velocity;
               
                // alright let's make the computer say something.
                if( velocity ) // note on
                {
                    keyPressed( note, velocity );
                    /*
                        depending on some variable(s) determining mode or the reaction to player input,
                        we send out shreds that play the piano or synth, these shreds' termination should 
                        depended upon the pressed & released events 
                    */
                }
                else // note off
                {
                    keyReleased( note, velocity );
                    /*
                        same as the note on block, if we want to start a process specifically at a note off,
                        this is where we would do it
                    */
                }
            }
            // if note off ( channel 1 (0) )
            else if( msg.data1 == 0x80 )
            {
                ;
            }
            // if control change ( we'll use this for pedal )
            else if( msg.data1 == 0xB0 )
            {
                if( msg.data2 == 67 && msg.data3 )
                {
                    // pool size for henon 
                    Math.round( Std.scalef( msg.data2, 0, 127, 1, 24 ) ) $ int => size;
                    // well the pedal is on
                    1 => pedalState;
                }
                else if( msg.data2 == 67 && !msg.data3 )
                {
                    // it's off now
                    0 => pedalState;
                }
            }
            // now z^-1
            now => timeOfLast;
        }
    }
}

// send an array of notes out, and wait to turn them off
// we keep the note on and off in a single shred since an event is what triggers this
// if we were to not keep a record of who triggered the computer generated note outs,
// then we could potentially lose track of all the keys being pressed and why
// if you played a chord, you'd likely track all the key presses of that chord and relate them to each other
// let's replicate that process here.
fun void out( Event @ off, int row[] )
{
    // let's do it!
    for( int i; i < row.size(); i++ )
    {
        // check whether this note is on already
        if( noteState[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 0, row[i], 54 ); // preset velocity, maybe we'll do something with that...
            1 => noteState[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( noteState[row[i]] ) // something could've changed!
        {
            midout.noteOff( 0, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteState[row[i]];
        }
    }
}

// overloaded version with velocity
fun void out( Event @ off, int row[], int velocity[] )
{
    // let's do it!
    for( int i; i < row.size(); i++ )
    {
        // check whether this note is on already
        if( noteState[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 0, row[i], velocity[i % velocity.size()] ); // preset velocity, maybe we'll do something with that...
            1 => noteState[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( noteState[row[i]] ) // something could've changed!
        {
            midout.noteOff( 0, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteState[row[i]];
        }
    }
}

// overloaded version with velocity
fun void out( Event @ off, int row[], int velocity[], dur space )
{
    // let's do it!
    for( int i; i < row.size(); i++ )
    {
        // check whether this note is on already
        if( noteState[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 0, row[i], velocity[i % velocity.size()] ); // preset velocity, maybe we'll do something with that...
            1 => noteState[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
            space => now;
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( noteState[row[i]] ) // something could've changed!
        {
            midout.noteOff( 0, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteState[row[i]];
        }
    }
}

// generate a row of pitches from an arbitrary algorithm
fun int[] fifths( int funda, int length )
{
    int row[0];
    // pack them into the array
    for( int i; i < length; i++ )
        if( funda + ( ( i + 1 ) * 7 ) < 127 ) 
            row << funda + ( ( i + 1 ) * 7 );
    // spit it out
    return row;
}

// generate a row of pitches from an arbitrary algorithm
fun int[] stack( int funda, int interval, int length )
{
    int row[0];
    // pack them into the array
    for( int i; i < length; i++ )
        if( funda + ( ( i + 1 ) * interval ) < 127 ) 
            row << funda + ( ( i + 1 ) * interval );
    // spit it out
    return row;
}

// flush out any keys that may be currently pressed
fun void flushShreds()
{
    // instead of just sending a ton of note off messages,
    // why don't we make all the active shreds turn off? then we don't hang
    for( int i; i < released.size(); i++ )
        released[i].broadcast();
}

fun void keyPressed( int note, int velocity )
{
    pressed[note].broadcast(); // signal
    1 => noteState[note]; // log state
    now => timePressed[note]; // when 
    velocity => pressedVelocity[note]; // velocity
}

fun void keyReleased( int note, int velocity )
{
    released[note].broadcast; // signal
    0 => noteState[note];
    now => timeReleased[note];
}