package com.helpshop.backend.repository;

import com.helpshop.backend.entity.SyncEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SyncEventRepository extends JpaRepository<SyncEventEntity, String> {
    List<SyncEventEntity> findByElderlyAccountIdOrderByCreatedAtDesc(String elderlyAccountId);
}
