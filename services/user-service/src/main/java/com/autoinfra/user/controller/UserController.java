package main.java.com.autoinfra.user.controller;

import com.autoinfra.user.dto.UserDto;
import com.autoinfra.user.service.UserService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/users")
public class UserController {
  private final UserService service;
  public UserController(UserService service) { this.service = service; }

  @PostMapping
  public UserDto create(@RequestBody UserDto dto) { return service.create(dto); }

  @GetMapping
  public List<UserDto> list() { return service.list(); }
}
