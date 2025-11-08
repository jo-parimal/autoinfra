package com.autoinfra.product.service;
import com.autoinfra.product.dto.ProductDto;
import java.util.List;

public interface ProductService {
  ProductDto create(ProductDto dto);
  List<ProductDto> list();
}
