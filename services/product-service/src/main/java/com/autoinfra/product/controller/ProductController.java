package main.java.com.autoinfra.product.controller;

import com.autoinfra.product.dto.ProductDto;
import com.autoinfra.product.service.ProductService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/products")
public class ProductController {
  private final ProductService service;
  public ProductController(ProductService service) { this.service = service; }

  @PostMapping
  public ProductDto create(@RequestBody ProductDto dto) { return service.create(dto); }

  @GetMapping
  public List<ProductDto> list() { return service.list(); }
}
