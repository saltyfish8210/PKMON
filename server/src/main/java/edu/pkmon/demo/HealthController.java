package edu.pkmon.demo;

import org.springframework.web.bind.annotation.*;

@RestController
public class HealthController {
    @GetMapping(value="/test/hello", produces="text/plain;charset=UTF-8")
    public String hello() { return "hello world\nPKMon Spring Boot backend is running.\n"; }
}
