public class LFO
{
    1.0 => float freq; // normalized
    float increment; // step size
    float phase; // current val
    60.0 => float fs;
    float lastSamp;
 
    fun @construct( float nFreq )
    {
        nFreq => freq;
        ( freq / fs ) * 2.0 * Math.pi => increment;
    }

    fun float tick() 
    {
        increment +=> phase;

        if( phase >= 2.0 * Math.pi )
            phase - ( 2.0 * Math.pi ) => phase;
        else if( phase <= -2.0 * Math.pi )
            phase + ( 2.0 * Math.pi ) => phase;

        Math.sin( phase ) => lastSamp;
        return lastSamp;
    }

    fun float last()
    {
        return lastSamp;
    }
}

//----------------- the idea part
/*
    an array of colors is combined in various ways over time
*/

// ===================== the chugl part ( if i copy my own code, do i credit myself? )
// eyes
GOrbitCamera cam => GG.scene().camera;
// position
cam.posZ( 10 );
// color
GG.scene().backgroundColor( Color.WHITE );
// GWindow.mouseMode( GWindow.MOUSE_DISABLED );
GWindow.fullscreen();
// the lfos ( blenders )
LFO blends[0];
// colors
vec3 colors[0];

while( true )
{
    // time zones
    GG.nextFrame() => now;
    // probability
    if( Math.randomf() < 0.25 )
        newColor( randomColor() );
    else if( Math.randomf() < 0.15 )
        removeColor();
    // lfos
    for( int i; i < blends.size(); i++ )
        blends[i].tick();
    // blend!
    weightedSum( colors, blends ) => GG.scene().backgroundColor;
}

// create new color
fun void newColor( vec3 color )
{
    colors << color;
    blends << new LFO( Math.randomf() * 0.05 ); // random frequency
}

// remove the eldest color
fun void removeColor()
{
    colors.popFront();
    blends.popFront();
}

// random color vector
fun vec3 randomColor()
{
    return @( Math.randomf(), Math.randomf(), Math.randomf() );
}

// exponentiate vector
fun vec3 expoVec( vec3 in )
{
    vec3 out;
    @( in.x * in.x, in.y * in.y, in.z * in.z ) @=> out;
    return out;
}

// weighted summation
fun vec3 weightedSum( vec3 palette[], LFO @ weights[] )
{
    // output
    vec3 out;
    // error catch
    if( palette.size() != weights.size() )
        return out;
    if( palette.size() == 0 )
        return out;
    // pool size
    palette.size() => int N;
    // blend!
    for( int i; i < N; i++ )
        ( 1.0 / N ) * palette[i] * Math.fabs( weights[i].last() ) +=> out;
    // the united states postal service
    return out;
}