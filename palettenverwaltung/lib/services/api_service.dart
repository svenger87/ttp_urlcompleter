import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/palette_type.dart';
import 'package:palettenverwaltung/constants.dart';
import '../models/customer.dart';
import '../models/overview.dart';
import '../models/booking.dart';
import '../models/customer_inventory_item.dart';
import '../models/palette_type_inventory_item.dart';

class ApiService {
  final String baseUrl;

  // Using the constant as default value
  ApiService({this.baseUrl = baseApiUrl});

  Future<List<PaletteType>> fetchPaletteTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/palette-types'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PaletteType.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load palette types');
    }
  }

  Future<PaletteType> createPaletteType(PaletteType paletteType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/palette-types'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(paletteType.toJson()),
    );
    if (response.statusCode == 201) {
      return PaletteType.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create palette type');
    }
  }

  Future<void> updatePaletteType(int id, PaletteType paletteType) async {
    final response = await http.put(
      Uri.parse('$baseUrl/palette-types/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(paletteType.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update palette type');
    }
  }

  Future<void> deletePaletteType(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/palette-types/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete palette type');
    }
  }

  Future<int> fetchPaletteTypeAvailability(int paletteTypeId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/palette-types/$paletteTypeId/available'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['available'];
    } else {
      throw Exception('Failed to fetch availability');
    }
  }

  Future<List<PaletteTypeInventoryItem>> fetchPaletteTypeInventory(
      int paletteTypeId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/palette-types/$paletteTypeId/inventory'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => PaletteTypeInventoryItem.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load palette type inventory');
    }
  }
// Customer endpoints

  Future<List<Customer>> fetchCustomers() async {
    final response = await http.get(Uri.parse('$baseUrl/customers'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Customer.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load customers');
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(customer.toJson()),
    );
    if (response.statusCode == 201) {
      return Customer.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create customer');
    }
  }

  Future<void> updateCustomer(int id, Customer customer) async {
    final response = await http.put(
      Uri.parse('$baseUrl/customers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(customer.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update customer');
    }
  }

  Future<void> deleteCustomer(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/customers/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete customer');
    }
  }

  // Bookings methods
  Future<List<Booking>> fetchBookings() async {
    final response = await http.get(Uri.parse('$baseUrl/bookings'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Booking.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load bookings');
    }
  }

  Future<Booking> createBooking(Booking booking) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    if (response.statusCode == 201) {
      return Booking.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create booking');
    }
  }

  Future<void> updateBooking(int id, Booking booking) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bookings/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(booking.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update booking');
    }
  }

  Future<void> deleteBooking(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/bookings/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete booking');
    }
  }

  // Overview endpoint
  Future<Overview> fetchOverview() async {
    final response = await http.get(Uri.parse('$baseUrl/overview'));
    if (response.statusCode == 200) {
      return Overview.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load overview data');
    }
  }

  Future<List<CustomerInventoryItem>> fetchCustomerInventory(
      int customerId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/customers/$customerId/inventory'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CustomerInventoryItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load customer inventory');
    }
  }
}
