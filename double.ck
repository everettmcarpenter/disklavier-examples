// number of the device to open (see: chuck --probe)
0 => int device;
// the midi event
MidiIn min;
// the message for retrieving data
MidiMsg msg;
// notes on rn
int noteStates[127];
// update accompaniment
Event accompWatch;
// waveguides
Blit guides[127];

0 => int debug;

// open the device
if( !min.open( device ) ) me.exit();

// print out device that was opened
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;

spork ~ accompaniment();
spork ~ diskListen();

while( true )
    1::day => now;

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
                    1 => noteStates[msg.data2];
                else
                    0 => noteStates[msg.data2];
                accompWatch.broadcast();
            }
        }
    }
}

fun void accompaniment()
{
    int active[127]; // this shred has it's own paperwork to keep track of
    while( true )
    {
        accompWatch => now;

        for( int i; i < noteStates.size(); i++ )
        {
            if( noteStates[i] != active[i] )
            {
                if( noteStates[i] )
                {
                    spork ~ note( guides[i], i );
                    1 => active[i];
                }
                else if( active[i] )
                    0 => active[i];
            }
        }
    }
}

fun void note( Blit @ waveguide, int note )
{
    if( debug )
        <<< "turning on guide ", note >>>;
    
    // too indecisive to write hardcoded parameters
    Math.random2( 0, dac.channels() - 1 ) => int myChan;

    waveguide => Gain vol( 0.095 ) => ExpEnv env => dac.chan( myChan );

    env.T60( 2::second + ( Math.randomf() * 2::second ) );
    waveguide.freq( Math.mtof( note ) );
    waveguide.harmonics( Math.random2( 1, 13 ) );
    waveguide.phase( Math.randomf() );

    env.keyOn( 1 );

    // play!
    while( noteStates[note] )
        1::ms => now;
    
    if( debug ) 
        <<< "turning off guide ", note >>>;

    // stop!
    waveguide =< env =< dac.chan( myChan );
}
