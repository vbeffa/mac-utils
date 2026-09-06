function run(argv) {
    var lat = parseFloat(argv[0]);
    var lon = parseFloat(argv[1]);

    if (!isFinite(lat) || !isFinite(lon)) {
        throw new Error("Latitude/longitude are invalid");
    }

    function rad(x) { return x * Math.PI / 180.0; }
    function deg(x) { return x * 180.0 / Math.PI; }
    function norm360(x) {
        x = x % 360.0;
        return x < 0 ? x + 360.0 : x;
    }

    // Compact solar-position calculation.  Sunrise/sunset uses the standard
    // apparent-horizon convention: solar center at -0.833 degrees.
    var jd = Date.now() / 86400000.0 + 2440587.5;
    var n = jd - 2451545.0;

    var meanLongitude = norm360(280.460 + 0.9856474 * n);
    var meanAnomaly = norm360(357.528 + 0.9856003 * n);
    var eclipticLongitude = norm360(
        meanLongitude +
        1.915 * Math.sin(rad(meanAnomaly)) +
        0.020 * Math.sin(rad(2.0 * meanAnomaly))
    );
    var obliquity = 23.439 - 0.0000004 * n;

    var rightAscension = norm360(deg(Math.atan2(
        Math.cos(rad(obliquity)) * Math.sin(rad(eclipticLongitude)),
        Math.cos(rad(eclipticLongitude))
    )));

    var declination = deg(Math.asin(
        Math.sin(rad(obliquity)) * Math.sin(rad(eclipticLongitude))
    ));

    var gmst = norm360(280.46061837 + 360.98564736629 * (jd - 2451545.0));
    var hourAngle = norm360(gmst + lon - rightAscension);
    if (hourAngle > 180.0) hourAngle -= 360.0;

    var elevation = deg(Math.asin(
        Math.sin(rad(lat)) * Math.sin(rad(declination)) +
        Math.cos(rad(lat)) * Math.cos(rad(declination)) * Math.cos(rad(hourAngle))
    ));

    var mode = elevation > -0.833 ? "light" : "dark";
    return mode + "|" + elevation.toFixed(3);
}
