package main.java.com.autoinfra.order.repo;
import com.autoinfra.order.entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrderRepository extends JpaRepository<Order, Long> {}
