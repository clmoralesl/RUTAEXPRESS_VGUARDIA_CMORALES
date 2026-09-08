package cl.duoc.rutaexpress.bff.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/test")
public class TestController {

    @GetMapping("/protegido")
    public ResponseEntity<Map<String, String>> protegido() {
        return ResponseEntity.ok(Map.of(
            "message", "Acceso exitoso al endpoint protegido",
            "status", "Authorized"
        ));
    }
}
