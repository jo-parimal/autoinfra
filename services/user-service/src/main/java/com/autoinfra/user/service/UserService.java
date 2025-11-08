package com.autoinfra.user.service;
import com.autoinfra.user.dto.UserDto;
import java.util.List;

public interface UserService {
  UserDto create(UserDto dto);
  List<UserDto> list();
}
