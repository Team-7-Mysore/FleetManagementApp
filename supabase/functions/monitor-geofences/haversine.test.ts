// Unit tests for haversine distance calculation
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

/**
 * Calculate distance between two coordinates using the Haversine formula
 * @param lat1 Latitude of first point in degrees
 * @param lon1 Longitude of first point in degrees
 * @param lat2 Latitude of second point in degrees
 * @param lon2 Longitude of second point in degrees
 * @returns Distance in meters
 */
function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371000; // Earth radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

// Test distance calculation accuracy with known coordinates
Deno.test("haversine - New York to Los Angeles distance", () => {
  // New York City coordinates
  const nyLat = 40.7128;
  const nyLon = -74.006;

  // Los Angeles coordinates
  const laLat = 34.0522;
  const laLon = -118.2437;

  const distance = haversineDistance(nyLat, nyLon, laLat, laLon);

  // Expected distance is approximately 3,944 km (3,944,000 meters)
  // Allow 1% tolerance for rounding
  const expected = 3944000;
  const tolerance = expected * 0.01;

  assertEquals(
    Math.abs(distance - expected) < tolerance,
    true,
    `Distance ${distance} should be within ${tolerance} of ${expected}`
  );
});

Deno.test("haversine - same location returns zero distance", () => {
  const lat = 37.7749;
  const lon = -122.4194;

  const distance = haversineDistance(lat, lon, lat, lon);

  assertEquals(distance, 0, "Distance between same coordinates should be 0");
});

Deno.test("haversine - short distance accuracy (1 km)", () => {
  // San Francisco coordinates
  const sfLat = 37.7749;
  const sfLon = -122.4194;

  // Approximately 1 km north
  const nearbyLat = 37.7839;
  const nearbyLon = -122.4194;

  const distance = haversineDistance(sfLat, sfLon, nearbyLat, nearbyLon);

  // Expected distance is approximately 1 km (1000 meters)
  // Allow 5% tolerance for short distances
  const expected = 1000;
  const tolerance = expected * 0.05;

  assertEquals(
    Math.abs(distance - expected) < tolerance,
    true,
    `Distance ${distance} should be within ${tolerance} of ${expected}`
  );
});

Deno.test("haversine - equator crossing", () => {
  // Point in northern hemisphere
  const lat1 = 10.0;
  const lon1 = 0.0;

  // Point in southern hemisphere
  const lat2 = -10.0;
  const lon2 = 0.0;

  const distance = haversineDistance(lat1, lon1, lat2, lon2);

  // Expected distance is approximately 2,223 km (20 degrees of latitude)
  const expected = 2223000;
  const tolerance = expected * 0.01;

  assertEquals(
    Math.abs(distance - expected) < tolerance,
    true,
    `Distance ${distance} should be within ${tolerance} of ${expected}`
  );
});

Deno.test("haversine - date line crossing (180° longitude)", () => {
  // Point just west of date line
  const lat1 = 0.0;
  const lon1 = 179.0;

  // Point just east of date line
  const lat2 = 0.0;
  const lon2 = -179.0;

  const distance = haversineDistance(lat1, lon1, lat2, lon2);

  // Expected distance is approximately 222 km (2 degrees of longitude at equator)
  const expected = 222000;
  const tolerance = expected * 0.05;

  assertEquals(
    Math.abs(distance - expected) < tolerance,
    true,
    `Distance ${distance} should be within ${tolerance} of ${expected}`
  );
});

Deno.test("haversine - north pole proximity", () => {
  // Point near north pole
  const lat1 = 89.0;
  const lon1 = 0.0;

  // Another point near north pole, different longitude
  const lat2 = 89.0;
  const lon2 = 90.0;

  const distance = haversineDistance(lat1, lon1, lat2, lon2);

  // At 89° latitude, longitude lines are very close together
  // Expected distance is approximately 78 km
  const expected = 78000;
  const tolerance = expected * 0.1; // 10% tolerance near poles

  assertEquals(
    Math.abs(distance - expected) < tolerance,
    true,
    `Distance ${distance} should be within ${tolerance} of ${expected}`
  );
});

Deno.test("haversine - south pole proximity", () => {
  // Point near south pole
  const lat1 = -89.0;
  const lon1 = 0.0;

  // Another point near south pole, different longitude
  const lat2 = -89.0;
  const lon2 = 180.0;

  const distance = haversineDistance(lat1, lon1, lat2, lon2);

  // At -89° latitude, longitude lines are very close together
  // Expected distance is approximately 156 km
  const expected = 156000;
  const tolerance = expected * 0.1; // 10% tolerance near poles

  assertEquals(
    Math.abs(distance - expected) < tolerance,
    true,
    `Distance ${distance} should be within ${tolerance} of ${expected}`
  );
});

Deno.test("haversine - performance with multiple calculations", () => {
  const iterations = 1000;
  const startTime = performance.now();

  for (let i = 0; i < iterations; i++) {
    haversineDistance(37.7749, -122.4194, 34.0522, -118.2437);
  }

  const endTime = performance.now();
  const totalTime = endTime - startTime;
  const avgTime = totalTime / iterations;

  // Each calculation should take less than 1ms on average
  assertEquals(
    avgTime < 1,
    true,
    `Average calculation time ${avgTime}ms should be less than 1ms`
  );
});
