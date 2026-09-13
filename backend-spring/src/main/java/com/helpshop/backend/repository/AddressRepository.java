package com.helpshop.backend.repository;

import com.helpshop.backend.entity.AddressEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AddressRepository extends JpaRepository<AddressEntity, String> {
    List<AddressEntity> findByElderlyAccountIdOrderByIsDefaultDescCreatedAtDesc(String elderlyAccountId);
}
