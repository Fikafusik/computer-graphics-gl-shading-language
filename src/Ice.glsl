
uniform sampler2D uniformIce;
uniform sampler2D uniformSnow;

uniform vec3      uniformResolution;

uniform float     uniformRotateAngle;
uniform float     uniformRoughness;
uniform float     uniformRefraction;

const float GEO_MAX_DIST  = 1000.0;
const int MATERIALID_NONE      = 0;
const int MATERIALID_FLOOR     = 1;
const int MATERIALID_ICE_OUTER = 2;
const int MATERIALID_ICE_INNER = 3;
const int MATERIALID_SKY       = 4;
const float PI             = 3.14159;

vec3 NORMALMAP_main(vec3 p, vec3 n);

float softshadow(vec3 ro, vec3 rd, float coneWidth);

float sdPlane( vec3 p ){
    return p.y;
}

float sdSphere( vec3 p, float s ){
    return length(p) - s;
}

float sdBox( vec3 p, vec3 b ){
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

struct DF_out{
    float d;
    int materialID;
};

DF_out map( in vec3 pos ){
    float dist = sdPlane(pos-vec3( -2.4) );

    dist = min(dist, sdSphere(pos - vec3(-0.5, 0.25, 0.0), 0.25));
    dist = min(dist, sdBox(pos - vec3( 0.5, 0.25, 0.0), vec3(0.25)));

    return DF_out(dist, MATERIALID_ICE_OUTER);
}

vec3 gradient( in vec3 p ){
    const float d = 0.001;
    return vec3(map(p+vec3(d,0,0)).d-map(p-vec3(d,0,0)).d,
    map(p+vec3(0,d,0)).d-map(p-vec3(0,d,0)).d,
    map(p+vec3(0,0,d)).d-map(p-vec3(0,0,d)).d);
}

vec2 castRay( const vec3 o, const vec3 d, const float tmin, const float eps, const bool bInternal){
    float tmax = 10.0, t = tmin, dist = GEO_MAX_DIST;
    for( int i=0; i<50; i++ ){
        vec3 p = o+d*t;
        dist = (bInternal?-1.:1.)*map(p).d;
        if( abs(dist)<eps || t>tmax ) {
            break;
        }
        t += dist;
    }
    dist = (dist<tmax)?dist:GEO_MAX_DIST;
    return vec2( t, dist );
}

float softshadow( vec3 o, vec3 L, float coneWidth ){
    float t = 0.0, minAperture = 1.0, dist = GEO_MAX_DIST;
    for( int i=0; i<6; i++ ){
        vec3 p = o+L*t; //Sample position = ray origin + ray direction * travel distance
        float dist = map( p ).d;
        float curAperture = dist/t; //Aperture ~= cone angle tangent (sin=dist/cos=travelDist)
        minAperture = min(minAperture,curAperture);
        t += 0.03 + dist; //0.03 : min step size.
    }
    return clamp(minAperture/coneWidth, 0.0, 1.0); //Should never exceed [0-1]. 0 = shadow, 1 = fully lit.
}

struct TraceData{
    float rayLen;
    vec3  rayDir;
    vec3  normal;
    int   materialID;
    vec3  matUVW;
    float alpha;
};

TraceData TRACE_getFront(const in TraceData tDataA, const in TraceData tDataB){
    if (tDataA.rayLen < tDataB.rayLen)
        return tDataA;
    else
        return tDataB;
}

TraceData TRACE_cheap(vec3 o, vec3 d){
    TraceData floorData;
    floorData.rayLen  = dot(vec3(-0.1)-o,vec3(0,1,0))/dot(d,vec3(0,1,0));

    if(floorData.rayLen<0.0) {
        floorData.rayLen = GEO_MAX_DIST;
    }

    floorData.rayDir  = d;
    floorData.normal  = vec3(0,1,0);
    floorData.matUVW  = o+d*floorData.rayLen;
    floorData.materialID   = MATERIALID_FLOOR;
    floorData.alpha   = 1.0;

    TraceData skyData;
    skyData.rayLen  = 50.0;
    skyData.rayDir  = d;
    skyData.normal  = -d;
    skyData.matUVW  = d;
    skyData.materialID   = MATERIALID_SKY;
    skyData.alpha   = 1.0;
    return TRACE_getFront(floorData,skyData);
}

TraceData TRACE_reflexion(vec3 o, vec3 d){
    return TRACE_cheap(o,d);
}

TraceData TRACE_geometry(vec3 o, vec3 d){
    TraceData cheapTrace = TRACE_cheap(o,d);

    TraceData iceTrace;
    vec2 rayLen_geoDist = castRay(o,d,0.1,0.0001,false);
    vec3 iceHitPosition = o+rayLen_geoDist.x*d;
    iceTrace.rayDir     = d;
    iceTrace.rayLen     = rayLen_geoDist.x;
    iceTrace.normal     = normalize(gradient(iceHitPosition));
    iceTrace.matUVW     = iceHitPosition;
    iceTrace.materialID      = MATERIALID_ICE_OUTER;
    iceTrace.alpha      = 0.0;

    return TRACE_getFront(cheapTrace,iceTrace);
}

TraceData TRACE_translucentDensity(vec3 o, vec3 d){
    TraceData innerIceTrace;

    vec2 rayLen_geoDist   = castRay(o,d,0.01,0.001,true).xy;
    vec3 iceExitPosition  = o+rayLen_geoDist.x*d;
    innerIceTrace.rayDir  = d;
    innerIceTrace.rayLen  = rayLen_geoDist.x;
    innerIceTrace.normal  = normalize(gradient(iceExitPosition));
    innerIceTrace.matUVW  = iceExitPosition;
    innerIceTrace.materialID   = MATERIALID_ICE_INNER;
    innerIceTrace.alpha   = rayLen_geoDist.x;
    return innerIceTrace;
}

vec3 NORMALMAP_smoothSampling(vec2 uv){
    vec2 x = fract(uv * 64.0 + 0.5);
    return texture(uniformIce, uv - x / 64.0 + (6.0 * x * x - 15.0 * x + 10.0) * x * x * x / 64.0, -100.0).xyz;
}

float NORMALMAP_triplanarSampling(vec3 p, vec3 n){
    float fTotal = abs(n.x)+abs(n.y)+abs(n.z);
    return (abs(n.x)*NORMALMAP_smoothSampling(p.yz).x
    +abs(n.y)*NORMALMAP_smoothSampling(p.xz).x
    +abs(n.z)*NORMALMAP_smoothSampling(p.xy).x)/fTotal;
}

float NORMALMAP_triplanarNoise(vec3 p, vec3 n){
    const mat2 m2 = mat2(0.90,0.44,-0.44,0.90);
    const float BUMP_MAP_UV_SCALE = 0.2;
    float fTotal = abs(n.x)+abs(n.y)+abs(n.z);
    float f1 = NORMALMAP_triplanarSampling(p*BUMP_MAP_UV_SCALE,n);
    p.xy = m2*p.xy; p.xz = m2*p.xz; p *= 2.1;
    float f2 = NORMALMAP_triplanarSampling(p*BUMP_MAP_UV_SCALE,n);
    p.yx = m2*p.yx; p.yz = m2*p.yz; p *= 2.3;
    float f3 = NORMALMAP_triplanarSampling(p*BUMP_MAP_UV_SCALE,n);
    return f1+0.5*f2+0.25*f3;
}

vec3 NORMALMAP_main(vec3 p, vec3 n){
    float d = 0.005;
    float po = NORMALMAP_triplanarNoise(p,n);
    return normalize(vec3((NORMALMAP_triplanarNoise(p+vec3(d,0,0),n)-po)/d,
    (NORMALMAP_triplanarNoise(p+vec3(0,d,0),n)-po)/d,
    (NORMALMAP_triplanarNoise(p+vec3(0,0,d),n)-po)/d));
}

struct Camera{
    vec3 R;
    vec3 U;
    vec3 D;
    vec3 o;
};

struct IceTracingData {
    TraceData reflectTraceData;
    TraceData translucentTraceData;
    TraceData exitTraceData;
};

IceTracingData renderIce(TraceData iceSurface, vec3 ptIce, vec3 dir){
    IceTracingData iceData;
    vec3 normalDelta = NORMALMAP_main(ptIce*uniformRoughness,iceSurface.normal)*uniformRoughness/10.;
    vec3 iceSurfaceNormal = normalize(iceSurface.normal+normalDelta);
    vec3 refract_dir = refract(dir,iceSurfaceNormal,1.0/uniformRefraction); //Ice refraction index = 1.31
    vec3 reflect_dir = reflect(dir,iceSurfaceNormal);

    //Trace reflection
    iceData.reflectTraceData = TRACE_reflexion(ptIce,reflect_dir);

    //Balance between refraction and reflection (not entirely physically accurate, Fresnel could be used here).
    float fReflectAlpha = 0.5*(1.0-abs(dot(normalize(dir),iceSurfaceNormal)));
    iceData.reflectTraceData.alpha = fReflectAlpha;
    vec3 ptReflect = ptIce+iceData.reflectTraceData.rayLen*reflect_dir;

    //Trace refraction
    iceData.translucentTraceData = TRACE_translucentDensity(ptIce,refract_dir);

    vec3 ptRefract = ptIce+iceData.translucentTraceData.rayLen*refract_dir;
    vec3 exitRefract_dir = refract(refract_dir,-iceData.translucentTraceData.normal,uniformRefraction);

    //This value fades around total internal refraction angle threshold.
    if(length(exitRefract_dir)<=0.95)
    {
        //Total internal reflection (either refraction or reflexion, to keep things cheap).
        exitRefract_dir = reflect(refract_dir,-iceData.translucentTraceData.normal);
    }

    //Trace environment upon exit.
    iceData.exitTraceData = TRACE_cheap(ptRefract,exitRefract_dir);
    iceData.exitTraceData.materialID = MATERIALID_FLOOR;

    return iceData;
}

vec4 MAT_apply(vec3 pos, TraceData traceData){
    if(traceData.materialID==MATERIALID_NONE)
        return vec4(0,0,0,1);
    if(traceData.materialID==MATERIALID_ICE_INNER)
        return vec4(0.4, 0.4, 1.0, 1.0);
    if(traceData.materialID==MATERIALID_SKY)
        return vec4(0.6,0.7,0.85,1.0);
    vec3 cDiff = pow(texture(uniformSnow, traceData.matUVW.xz).rgb, vec3(1.2));
    float dfss = softshadow(pos, normalize(vec3(-0.6,0.7,-0.5)), 0.07);
    return vec4(cDiff * (0.45 + 1.2 * (dfss)), 1);
}

void main(void){

    vec2 uv = (gl_FragCoord.xy-0.5*uniformResolution.xy) / uniformResolution.xx;
    float rotX = uniformRotateAngle;
    Camera camera;
    camera.o = vec3(cos(rotX),0.575,sin(rotX))*2.3;
    camera.D = normalize(vec3(0,-0.25,0)-camera.o);
    camera.R = normalize(cross(camera.D,vec3(0,1,0)));
    camera.U = cross(camera.R,camera.D);
    vec2 cuv = uv*2.0*uniformResolution.x/uniformResolution.y;//camera uv
    vec3 dir = normalize(cuv.x*camera.R+cuv.y*camera.U+camera.D*2.5);

    vec3 ptReflect = vec3(0);
    TraceData geometryTraceData = TRACE_geometry(camera.o, dir);
    vec3 ptGeometry = camera.o+geometryTraceData.rayLen*dir;

    IceTracingData iceData;
    iceData.translucentTraceData.rayLen = 0.0;
    if(geometryTraceData.materialID == MATERIALID_ICE_OUTER && geometryTraceData.rayLen < GEO_MAX_DIST){
        vec3 ptIce = ptGeometry;
        iceData = renderIce(geometryTraceData, ptIce, dir);
        geometryTraceData = iceData.exitTraceData;
        vec3 ptRefract = ptIce+iceData.translucentTraceData.rayLen*iceData.translucentTraceData.rayDir;
        ptReflect = ptIce+iceData.reflectTraceData.rayLen*iceData.reflectTraceData.rayDir;
        ptGeometry = ptRefract+geometryTraceData.rayLen*dir;
    }
    vec4 cTerrain  = MAT_apply(ptGeometry,geometryTraceData);
    vec4 cIceInner = MAT_apply(ptGeometry,iceData.translucentTraceData);
    vec4 cReflect  = MAT_apply(ptReflect,iceData.reflectTraceData);
    if(iceData.translucentTraceData.rayLen > 0.0 ){
        float fTrav = iceData.translucentTraceData.rayLen;
        vec3 cRefract = cTerrain.rgb;
        cRefract.rgb = mix(cRefract,cIceInner.rgb,0.3*fTrav+0.2*sqrt(fTrav*3.0));
        cRefract.rgb += fTrav*0.3;
        vec3 cIce = mix(cRefract,cReflect.rgb,iceData.reflectTraceData.alpha);
        gl_FragColor.rgb = cIce;
    }
    else {
        gl_FragColor.rgb = cTerrain.rgb;
    }

    float sin2 = uv.x * uv.x + uv.y * uv.y;
    float cos2 = 1.0-min(sin2*sin2,1.0);
    gl_FragColor.rgb = pow(gl_FragColor.rgb*cos2*cos2, vec3(0.4545)); //2.2 Gamma compensation
}
