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
// exit tickets 
Event signal[127];
// notes that are actively on, whether through human input or computer
int noteOn[127];

spork ~ in();

while( true )
    1::day => now;

fun void in()
{
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
            // if note on ( this is for channel 1 )
            if( msg.data1 == 0x90 )
            {
                // this is the note
                msg.data2 => int note;
                // this is the velocity
                msg.data3 => int velocity;
                // alright let's make the computer say something.
                spork ~ out( signal[note], fifths( note, 4 ), [velocity] );
            }
            // if note off ( channel 1 )
            else if( msg.data1 == 0x80 )
            {
                // this is the note
                msg.data2 => int note;
                // alright let's make the computer say something.
                signal[note].broadcast();
            }
            // if control change ( we'll use this for pedal )
            else if( msg.data1 == 0xB0 )
            {
                if( msg.data2 == 67 )
                    flushShreds();
            }
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
        if( noteOn[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 1, row[i], 54 ); // preset velocity, maybe we'll do something with that...
            1 => noteOn[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( noteOn[row[i]] ) // something could've changed!
        {
            midout.noteOff( 1, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteOn[row[i]];
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
        if( noteOn[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 1, row[i], velocity[i % velocity.size()] ); // preset velocity, maybe we'll do something with that...
            1 => noteOn[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( noteOn[row[i]] ) // something could've changed!
        {
            midout.noteOff( 1, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteOn[row[i]];
        }
    }
}

// generate a row of pitches from an arbitrary algorithm
fun int[] fifths( int funda, int length )
{
    int row[0];
    // pack them into the array
    for( int i; i < length; i++ )
        if( funda + ( ( i + 1 ) * 7 ) <= 127 ) 
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
        if( funda + ( ( i + 1 ) * interval ) <= 127 ) 
            row << funda + ( ( i + 1 ) * interval );
    // spit it out
    return row;
}

// flush out any keys that may be currently pressed
fun void flushShreds()
{
    // instead of just sending a ton of note off messages,
    // why don't we make all the active shreds turn off? then we don't hang
    for( int i; i < signal.size(); i++ )
        signal[i].broadcast();
}