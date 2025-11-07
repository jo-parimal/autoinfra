package main.java.com.autoinfra.user.service;
import com.autoinfra.user.dto.UserDto;
import com.autoinfra.user.entity.User;
import com.autoinfra.user.repo.UserRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class UserServiceImpl implements UserService {
  private final UserRepository repo;
  public UserServiceImpl(UserRepository repo){ this.repo = repo; }

  @Override
  public UserDto create(UserDto dto) {
    User u = new User();
    u.setName(dto.getName());
    u.setEmail(dto.getEmail());
    User saved = repo.save(u);
    UserDto out = new UserDto();
    out.setId(saved.getId()); out.setName(saved.getName()); out.setEmail(saved.getEmail());
    return out;
  }

  @Override
  public List<UserDto> list() {
    return repo.findAll().stream().map(u -> {
      UserDto d = new UserDto();
      d.setId(u.getId()); d.setName(u.getName()); d.setEmail(u.getEmail());
      return d;
    }).collect(Collectors.toList());
  }
}
