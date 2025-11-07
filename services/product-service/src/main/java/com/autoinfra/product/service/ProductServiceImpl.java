package main.java.com.autoinfra.product.service;
import com.autoinfra.product.dto.ProductDto;
import com.autoinfra.product.entity.Product;
import com.autoinfra.product.repo.ProductRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProductServiceImpl implements ProductService {
  private final ProductRepository repo;
  public ProductServiceImpl(ProductRepository repo){ this.repo = repo; }

  @Override
  public ProductDto create(ProductDto dto) {
    Product p = new Product();
    p.setName(dto.getName());
    p.setPrice(dto.getPrice());
    Product saved = repo.save(p);
    ProductDto out = new ProductDto();
    out.setId(saved.getId()); out.setName(saved.getName()); out.setPrice(saved.getPrice());
    return out;
  }

  @Override
  public List<ProductDto> list() {
    return repo.findAll().stream().map(p -> {
      ProductDto d = new ProductDto();
      d.setId(p.getId()); d.setName(p.getName()); d.setPrice(p.getPrice());
      return d;
    }).collect(Collectors.toList());
  }
}
