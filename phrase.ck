// number of the device to open (see: chuck --probe)
0 => int indevice;
1 => int outdevice;
// the midi event
MidiIn min;
// the message for retrieving data
MidiMsg msg;
// 
MidiOut midout;
// notes on rn
int noteStates[127];
// update accompaniment
Event accompWatch;
// waveguides
Blit guides[127];
// active note shreds
int active[127]; // paperwork

1 => int debug;

// open the device
if( !min.open( indevice ) ) me.exit();

// open the device
if( !midout.open( outdevice ) ) me.exit();

// print out device that was opened
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;

// print out device that was opened
<<< "MIDI device:", midout.num(), " -> ", midout.name() >>>;

spork ~ diskListen();
spork ~ diskOut();

while( true )
    1::day => now;

fun void diskOut()
{
    int responding[127];
    while( true )
    {
        min => now;
        for( int i; i < 127; i++ )
        {
            if( responding[i] != noteStates[i] )
            {
                if( noteStates[i] )
                {
                    createRow( i ) @=> int row[];
                    for( int i; i < row.size(); i++ )
                    {
                        midout.noteOn( 0, row[i], 52 );
                    }
                    1 => responding[i];
                }
                else if( responding[i] )
                {
                    createRow( i ) @=> int row[];
                    for( int i; i < row.size(); i++ )
                    {
                        midout.noteOff( 0, row[i], 0 );
                    }
                    0 => responding[i];
                }
            }
        }
    }
}

fun int[] createRow( int note )
{
    5 => int length;
    int row[0];
    for( int i; i < length; i++ )
        row << note + ( ( i + 1 ) * 7 );
    return row;
}

fun void diskListen()
{
    // infinite time-loop
    while( true )
    {
        // wait on the event 'min'
        min => now;

        // get the message(s)
        while( min.recv( msg ) )
        {
            if( msg.data1 == 144 )
            {
                if( msg.data3 )
                {
                    1 => noteStates[msg.data2];
                    spork ~ note( guides[msg.data2], msg.data2 );
                }
                else
                    0 => noteStates[msg.data2];
                accompWatch.broadcast();
            }
            else if( msg.data1 == 176 )
            {
                if( msg.data2 == 67 )
                {
                    flush();
                }
            }
        }
    }
}

fun void note( Blit @ waveguide, int note )
{
    if( active[note] ) 
        me.exit();
    
    1 => active[note];
    
    // too indecisive to write hardcoded parameters
    Math.random2( 0, dac.channels() - 1 ) => int myChan;

    Envelope env;

    while( noteStates[note] )
    {
        if( debug )
            <<< "turning on guide ", note >>>;

        0.5::second + ( Math.randomf() * 2::second ) => dur noteLength;
        env.duration( noteLength );
        waveguide.freq( Math.mtof( note + 12 ) );
        waveguide.harmonics( Math.random2( 1, 13 ) );
        waveguide.phase( Math.randomf() );

        waveguide => Gain vol( 0.075 ) => env => dac.chan( myChan );

        env.keyOn();

        // play!
        noteLength => now;

        env.keyOff();

        noteLength => now;

        if( debug ) 
            <<< "turning off guide ", note >>>;
    }

    if( env.keyOn() )
    {
        env.keyOff();
        env.duration() => now;
    }

    // stop!
    waveguide =< env =< dac.chan( myChan );
    0 => active[note];
}

fun void flush()
{
    for( int i; i < 127; i++ )
        midout.noteOff( 0, i, 0 );
}