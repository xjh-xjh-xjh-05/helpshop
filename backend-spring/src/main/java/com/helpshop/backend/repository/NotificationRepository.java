package com.helpshop.backend.repository;

import com.helpshop.backend.entity.NotificationEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<NotificationEntity, String> {
    List<NotificationEntity> findByElderlyAccountIdOrderByCreatedAtDesc(String elderlyAccountId);
    List<NotificationEntity> findByChildAccountIdOrderByCreatedAtDesc(String childAccountId);
}
