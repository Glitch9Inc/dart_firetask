# Firetask: Firestore CRUD Controller Module

This module provides a set of controllers designed to simplify **CRUD (Create, Read, Update, Delete)** operations in Firebase Firestore. It enables a structured approach for managing Firestore documents and collections, offering reusable components for various document-based data handling requirements.

## Key Features

### 1. **Base Firestore CRUD Controller**
   - A generic base class that abstracts common Firestore operations, reducing boilerplate code for interacting with Firestore documents.
   - Handles CRUD operations efficiently for different Firestore collections.
   - Customizable for specific collection structures.

### 2. **Collection CRUD Controller**
   - Extends the base controller to manage Firestore collections with a focus on batch operations and collection-level interactions.
   - Allows for scalable handling of large datasets and multiple document operations.

### 3. **Date-based Document CRUD Controller**
   - A specialized controller for managing documents organized by dates, such as task scheduling, event logs, or time-based data records.
   - Ensures optimized queries and retrieval for date-based filtering.

### 4. **Document CRUD Controller**
   - Focuses on managing single Firestore documents, providing granular control over individual data points.
   - Handles operations such as retrieving, updating, and deleting specific documents.

### 5. **Firetask and Firetask Batch**
   - A task management system built on Firestore, allowing for complex task execution and batch operations.
   - Supports transactional operations and ensures data consistency across multiple tasks.

### 6. **Firestore Data Type Handling**
   - Contains utility functions for handling and validating Firestore data types, ensuring that data types used in the database are consistent with Firestore’s requirements.

### 7. **Firestore Validator**
   - Provides validation utilities for Firestore documents, ensuring that data meets predefined rules before being saved or updated.
   - Helps maintain data integrity within the Firestore collections.

## Benefits
- **Modular Design**: The controllers are modular, allowing you to extend or customize them to meet specific project needs.
- **Code Reusability**: Eliminates redundant code by providing common functions for Firestore interactions.
- **Scalable Operations**: Supports batch processing and large-scale Firestore document management.
- **Optimized for Date-based Data**: The date-based controller is perfect for applications that need time-sensitive or chronologically structured data.

## Usage
To use any of these controllers, simply import the respective Dart files into your project and extend or customize them as needed. These controllers offer a flexible way to manage Firestore data without rewriting CRUD operations for each Firestore collection.

## Installation
1. Add the relevant Dart files to your Flutter project.
2. Ensure your project has the `cloud_firestore` dependency installed.

```yaml
dependencies:
  cloud_firestore: ^3.1.5
