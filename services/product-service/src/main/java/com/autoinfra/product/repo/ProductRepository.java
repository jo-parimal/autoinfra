package main.java.com.autoinfra.product.repo;
import com.autoinfra.product.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, Long> {}
