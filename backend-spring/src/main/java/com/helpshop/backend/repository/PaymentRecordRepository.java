package com.helpshop.backend.repository;

import com.helpshop.backend.entity.PaymentRecordEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface PaymentRecordRepository extends JpaRepository<PaymentRecordEntity, String> {
    List<PaymentRecordEntity> findByElderlyAccountIdOrderByCreatedAtDesc(String elderlyAccountId);

    @Modifying
    @Transactional
    @Query("DELETE FROM PaymentRecordEntity p WHERE p.orderId = :orderId")
    void deleteByOrderId(@Param("orderId") String orderId);
}
