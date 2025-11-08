package com.autoinfra.order.service;
import com.autoinfra.order.dto.OrderDto;
import com.autoinfra.order.entity.Order;
import com.autoinfra.order.repo.OrderRepository;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class OrderServiceImpl implements OrderService {
  private final OrderRepository repo;
  public OrderServiceImpl(OrderRepository repo){ this.repo = repo; }

  @Override
  public OrderDto create(OrderDto dto) {
    Order o = new Order();
    o.setUserId(dto.getUserId());
    o.setProductId(dto.getProductId());
    o.setQuantity(dto.getQuantity());
    Order saved = repo.save(o);
    OrderDto out = new OrderDto();
    out.setId(saved.getId());
    out.setUserId(saved.getUserId());
    out.setProductId(saved.getProductId());
    out.setQuantity(saved.getQuantity());
    return out;
  }

  @Override
  public List<OrderDto> list() {
    return repo.findAll().stream().map(o -> {
      OrderDto d = new OrderDto();
      d.setId(o.getId()); d.setUserId(o.getUserId()); d.setProductId(o.getProductId()); d.setQuantity(o.getQuantity());
      return d;
    }).collect(Collectors.toList());
  }
}
