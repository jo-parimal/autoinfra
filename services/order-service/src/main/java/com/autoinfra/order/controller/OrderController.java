package main.java.com.autoinfra.order.controller;
import com.autoinfra.order.dto.OrderDto;
import com.autoinfra.order.service.OrderService;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/orders")
public class OrderController {
  private final OrderService service;
  public OrderController(OrderService service){ this.service = service; }

  @PostMapping
  public OrderDto create(@RequestBody OrderDto dto){ return service.create(dto); }

  @GetMapping
  public List<OrderDto> list(){ return service.list(); }
}
