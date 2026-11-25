package edu.pkmon.capture.web;

import edu.pkmon.capture.dto.CaptureDtos.ApiEnvelope;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.capture.port.SpeciesCatalog;
import edu.pkmon.capture.repository.Repositories.CaptureRecordRepository;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;
import edu.pkmon.study.domain.Geo;
import edu.pkmon.study.port.TaskRepository;
import org.springframework.web.bind.annotation.*;
import java.time.Clock;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/capture")
public record NearbyController(CurrentUserProvider users, SpawnRepository spawns, CaptureRecordRepository records,
                               TaskRepository tasks, SpeciesCatalog species, Clock clock) {
    public record Marker(String spawnId, String speciesId, String name, String iconKey, long distanceMeters,
                         String regionName, double latitude, double longitude) {}
    @GetMapping("/nearby")
    public ApiEnvelope nearby(@RequestParam double lat, @RequestParam double lng, @RequestParam double radius) {
        String user = users.currentUserId();
        if (!Double.isFinite(lat) || !Double.isFinite(lng) || !Double.isFinite(radius) || Math.abs(lat)>90
                || Math.abs(lng)>180 || radius<0 || radius>20000) throw new IllegalArgumentException("坐标或半径无效（0–20000 米）");
        var captured = records.findByUser(user).stream().map(item -> item.spawnId()).collect(Collectors.toSet());
        var markers = new ArrayList<Marker>();
        for (var spawn : spawns.activeFor(user, clock.instant())) {
            if (captured.contains(spawn.spawnId())) continue;
            var region = tasks.findRegion(spawn.regionId()).orElse(null);
            var entry = species.details(spawn.speciesId()).orElse(null);
            if (region == null || !region.enabled() || entry == null) continue;
            double distance = Geo.distanceMeters(lat, lng, region.centerLatitude(), region.centerLongitude());
            if (distance <= radius) markers.add(new Marker(spawn.spawnId(), entry.speciesId(), entry.name(),
                    entry.imageKey().replace("assets/sprites/", "").replace(".png", ""), Math.round(distance),
                    "library_entrance".equals(region.regionId()) ? "图书馆" : region.regionId(),
                    region.centerLatitude(), region.centerLongitude()));
        }
        markers.sort(Comparator.comparingLong(Marker::distanceMeters).thenComparing(Marker::spawnId));
        return ApiEnvelope.ok(Map.of("items", markers));
    }
}
