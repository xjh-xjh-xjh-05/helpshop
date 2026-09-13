package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "product_mock")
public class ProductEntity {
    @Id
    public String id;
    @Column(nullable = false)
    public String platform;
    @Column(nullable = false)
    public String name;
    @Column(nullable = false)
    public Double price;
    public Double rating;
    public Integer sales;
    @Column(name = "shop_name")
    public String shopName;
    public String description;
    public String tags;
    @Column(name = "image_key")
    public String imageKey;
    @Column(name = "image_url")
    public String imageUrl;
    @Column(name = "recommend_score")
    public Double recommendScore;

    public ProductEntity() {
    }
}
