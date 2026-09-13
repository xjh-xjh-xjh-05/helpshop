package com.helpshop.backend.repository;

import com.helpshop.backend.entity.ProductEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ProductRepository extends JpaRepository<ProductEntity, String> {
    List<ProductEntity> findAllByOrderBySalesDescRatingDesc();
}
