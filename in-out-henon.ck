////////==========================
// 
//      play two notes, velocities 
//      are alpha and beta
//
//      pitches are the 
//      fundamentals 
//       
//      left most pedal determines
//      amount of points sampled
//      from henon
//
//      henon sampling occurs when
//      alpha and beta are played
//
//      x of henon is pitch
//      y of henon is velocity
//
////////==========================

// awesome synth voice
class BlitVoice extends Chugraph
{
    Blit blt => Gain volume( 0.05 ) => Envelope env( 1::second ) => outlet;

    fun dur noteOn( int note )
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
}

class Note
{
    int pitch;
    int velocity;
    time when;

    fun @construct( MidiMsg msg )
    {
        this.set( msg, now );
    } 

    fun @construct( Note n )
    {
        n.pitch => this.pitch;
        n.velocity => this.velocity;
        n.when => this.when;
    } 

    // we're assuming this msg is a note message!
    fun void set( MidiMsg msg, time w )
    {
        msg.data2 => pitch;
        msg.data3 => velocity;
        w => when;
    }
}

// duple
class Duple 
{
    Note @ x;
    Note @ y;

    int isFull;

    fun @construct( Duple m )
    {
        this.copy( this, m );
    }

    fun void put( Note n )
    {
        if( !x ) // if x doesn't exist, this new note is x!
        {
            new Note @=> x;
            copy( n, x );
        }
        else if( !y ) // if x exists and y doesn't, this new note is y!
        {
            new Note @=> y;
            copy( n, y ); 
        }
        
        // let's check
        if( x && y )
            1 => isFull;
    }

    fun void empty() { null @=> x; null @=> y; 0 => isFull; }

    fun int full() { return isFull; }

    fun void copy( Note copy, Note paste )
    {
        copy.pitch => paste.pitch;
        copy.velocity => paste.velocity;
        copy.when => paste.when;
    }

    fun void copy( Duple copy, Duple paste )
    {
        if( copy.x )
            new Note( copy.x ) @=> paste.x;
        if( copy.y )
            new Note( copy.y ) @=> paste.y;
        
        copy.isFull => paste.isFull;
    }
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
// exit tickets 
Event signal[127];
// 
Event pressed[127];
Event released[127];

// waveguides
BlitVoice blts[127];

// notes that are actively on, whether through human input or computer
int noteOn[127];
// synths that are on
int synthOn[127];

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

// ===================== the chugl part ( if i copy my own code, do i credit myself? )
// eyes
GOrbitCamera cam => GG.scene().camera;
// position
cam.posZ( 10 );
// color
GG.scene().backgroundColor( Color.WHITE );
// GWindow.mouseMode( GWindow.MOUSE_DISABLED );
GWindow.fullscreen();

// listen to me!
spork ~ in();

// wait
while( true )
{
    // time zones
    GG.nextFrame() => now;
}

fun void in()
{
    // last msg
    time timeOfLast; // oh boy now we have memory
    // state of pedal
    int pedalState;
    // our duple struct
    Duple myDuple;
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
                if( velocity )
                {
                    // if we need to push something into the buffer
                    if( !myDuple.full() )
                    {
                        Note myNote( msg ); // create our instance to pass
                        myDuple.put( myNote ); // push it into the duple ( it will copy so that the above class can disappear )
                    }
                    
                    // it could be that this note was the last needed element
                    if( myDuple.full() )
                    {
                        spork ~ henonNote( myDuple, size, 1::second, midout ); // this will copy the duple so we can keep using it here
                        myDuple.empty(); // empty
                    }

                    // synth
                    // spork ~ synthOut( signal[note], stack( note, 5, 4 ) );
                    // color~
                    @( Math.randomf(), Math.randomf(), Math.randomf() ) => GG.scene().backgroundColor;
                }
                // alright let's make the computer not say something.
                else
                    turnOff( note );
                
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
        if( noteOn[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 0, row[i], 54 ); // preset velocity, maybe we'll do something with that...
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
            midout.noteOff( 0, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
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
            midout.noteOn( 0, row[i], velocity[i % velocity.size()] ); // preset velocity, maybe we'll do something with that...
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
            midout.noteOff( 0, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteOn[row[i]];
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
        if( noteOn[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            midout.noteOn( 0, row[i], velocity[i % velocity.size()] ); // preset velocity, maybe we'll do something with that...
            1 => noteOn[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
            space => now;
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( noteOn[row[i]] ) // something could've changed!
        {
            midout.noteOff( 0, row[i], 0 ); // off velocity doesn't really matter with pianos, i think...
            0 => noteOn[row[i]];
        }
    }
}

// overloaded version with velocity
fun void synthOut( Event @ off, int row[] )
{
    // wait
    dur wait;
    // let's do it!
    for( int i; i < row.size(); i++ )
    {
        // check whether this note is on already
        if( synthOn[row[i]] )
        {
            ; // we won't do anything for now
        }
        else // if not, let's have fun
        {
            blts[row[i]] => dac.chan( Math.random2( 0, dac.channels() - 1 ) );
            blts[row[i]].noteOn( row[i] ); // preset velocity, maybe we'll do something with that...
            1 => synthOn[row[i]]; // now that we've pressed the key, make sure everyone know's that key is on!
        }
    }

    // wait till someone tell's us to stop the music
    off => now;

    // alright no more playing the piano.
    for( int i; i < row.size(); i++ )
    {
        if( synthOn[row[i]] ) // something could've changed!
        {
            blts[row[i]].noteOff() => wait; // off velocity doesn't really matter with pianos, i think...
        }
    }
    
    // fade out
    wait => now;
    
    // unpatch
    for( int i; i < row.size(); i++ )
    {
        if( synthOn[row[i]] ) // something could've changed!
        {
            blts[row[i]] =< dac; // off velocity doesn't really matter with pianos, i think...
            0 => synthOn[row[i]];
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
    for( int i; i < signal.size(); i++ )
        signal[i].broadcast();
}

// end the active shreds
fun void turnOff( int note )
{
	signal[note].broadcast();
	0 => noteOn[note];
}

// henon map!
fun vec3[] henon( float alpha, float beta, int poolSize )
{
    vec3 positions[1];
    for( int i; i < poolSize; i++ )
    {
        // x 
        ( positions[i].y  + 1.0 - alpha * ( positions[i].x * positions[i].x ) ) => float x;
        ( beta * positions[i].x ) => float y;
        
        if( x >= 4.0 || x <= -4.0 )
            Math.cos( x ) => x;
        if( y >= 4.0 || y <= -4.0 )
            Math.sin( y ) => y;

        // point
        positions << @( x , y , 0 );
    }

    // pop out the first since it is just zero
    positions.popFront();

    return positions;
}

// send out a bunch of notes determined by the henon map
fun void henonNote( Duple notes, int poolSize, dur length, MidiOut @ output )
{
    // make our own copy
    Duple base( notes );
    // calculate alpha and beta parameters
    Std.scalef( base.x.pitch, 0, 127, 0.0, 2.4 ) => float alpha;
    Std.scalef( base.y.pitch, 0, 127, 0.0, 1.8 ) => float beta;
    // sample map
    henon( alpha, beta, poolSize ) @=> vec3 pool[];
    // create midi notes
    MidiMsg notes[poolSize];
    // let's send them
    for( int i; i < poolSize; i++ )
    {
        // interpret and set the note
        Math.round( pool[i].x * 127.0 ) $ int => int note;
        // the same for velocity
        Math.round( pool[i].y * 127.0 ) $ int => int velocity;
    }
}