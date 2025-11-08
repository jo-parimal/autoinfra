package com.autoinfra.order.service;
import com.autoinfra.order.dto.OrderDto;
import java.util.List;

public interface OrderService {
  OrderDto create(OrderDto dto);
  List<OrderDto> list();
}
