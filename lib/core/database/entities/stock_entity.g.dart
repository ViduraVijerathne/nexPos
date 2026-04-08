// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStockEntityCollection on Isar {
  IsarCollection<StockEntity> get stockEntitys => this.collection();
}

const StockEntitySchema = CollectionSchema(
  name: r'StockEntity',
  id: 2841630848568427563,
  properties: {
    r'availableQuantity': PropertySchema(
      id: 0,
      name: r'availableQuantity',
      type: IsarType.long,
    ),
    r'barcode': PropertySchema(
      id: 1,
      name: r'barcode',
      type: IsarType.string,
    ),
    r'buyingPrice': PropertySchema(
      id: 2,
      name: r'buyingPrice',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'expiryDate': PropertySchema(
      id: 4,
      name: r'expiryDate',
      type: IsarType.dateTime,
    ),
    r'grnCode': PropertySchema(
      id: 5,
      name: r'grnCode',
      type: IsarType.string,
    ),
    r'initialQuantity': PropertySchema(
      id: 6,
      name: r'initialQuantity',
      type: IsarType.long,
    ),
    r'maxDiscount': PropertySchema(
      id: 7,
      name: r'maxDiscount',
      type: IsarType.double,
    ),
    r'productBarcode': PropertySchema(
      id: 8,
      name: r'productBarcode',
      type: IsarType.string,
    ),
    r'productName': PropertySchema(
      id: 9,
      name: r'productName',
      type: IsarType.string,
    ),
    r'sellingPrice': PropertySchema(
      id: 10,
      name: r'sellingPrice',
      type: IsarType.double,
    ),
    r'status': PropertySchema(
      id: 11,
      name: r'status',
      type: IsarType.byte,
      enumMap: _StockEntitystatusEnumValueMap,
    ),
    r'updatedAt': PropertySchema(
      id: 12,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _stockEntityEstimateSize,
  serialize: _stockEntitySerialize,
  deserialize: _stockEntityDeserialize,
  deserializeProp: _stockEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'barcode': IndexSchema(
      id: 1156800733621869998,
      name: r'barcode',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'barcode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'productName': IndexSchema(
      id: 4701636579502142930,
      name: r'productName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'productName',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'productBarcode': IndexSchema(
      id: -2628887120658537116,
      name: r'productBarcode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'productBarcode',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'grnCode': IndexSchema(
      id: -8506422936547329836,
      name: r'grnCode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'grnCode',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _stockEntityGetId,
  getLinks: _stockEntityGetLinks,
  attach: _stockEntityAttach,
  version: '3.1.0+1',
);

int _stockEntityEstimateSize(
  StockEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.barcode.length * 3;
  {
    final value = object.grnCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.productBarcode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.productName.length * 3;
  return bytesCount;
}

void _stockEntitySerialize(
  StockEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.availableQuantity);
  writer.writeString(offsets[1], object.barcode);
  writer.writeDouble(offsets[2], object.buyingPrice);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeDateTime(offsets[4], object.expiryDate);
  writer.writeString(offsets[5], object.grnCode);
  writer.writeLong(offsets[6], object.initialQuantity);
  writer.writeDouble(offsets[7], object.maxDiscount);
  writer.writeString(offsets[8], object.productBarcode);
  writer.writeString(offsets[9], object.productName);
  writer.writeDouble(offsets[10], object.sellingPrice);
  writer.writeByte(offsets[11], object.status.index);
  writer.writeDateTime(offsets[12], object.updatedAt);
}

StockEntity _stockEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StockEntity();
  object.availableQuantity = reader.readLong(offsets[0]);
  object.barcode = reader.readString(offsets[1]);
  object.buyingPrice = reader.readDouble(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.expiryDate = reader.readDateTimeOrNull(offsets[4]);
  object.grnCode = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.initialQuantity = reader.readLong(offsets[6]);
  object.maxDiscount = reader.readDouble(offsets[7]);
  object.productBarcode = reader.readStringOrNull(offsets[8]);
  object.productName = reader.readString(offsets[9]);
  object.sellingPrice = reader.readDouble(offsets[10]);
  object.status =
      _StockEntitystatusValueEnumMap[reader.readByteOrNull(offsets[11])] ??
          StockEntityStatus.active;
  object.updatedAt = reader.readDateTimeOrNull(offsets[12]);
  return object;
}

P _stockEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    case 11:
      return (_StockEntitystatusValueEnumMap[reader.readByteOrNull(offset)] ??
          StockEntityStatus.active) as P;
    case 12:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _StockEntitystatusEnumValueMap = {
  'active': 0,
  'inactive': 1,
};
const _StockEntitystatusValueEnumMap = {
  0: StockEntityStatus.active,
  1: StockEntityStatus.inactive,
};

Id _stockEntityGetId(StockEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _stockEntityGetLinks(StockEntity object) {
  return [];
}

void _stockEntityAttach(
    IsarCollection<dynamic> col, Id id, StockEntity object) {
  object.id = id;
}

extension StockEntityByIndex on IsarCollection<StockEntity> {
  Future<StockEntity?> getByBarcode(String barcode) {
    return getByIndex(r'barcode', [barcode]);
  }

  StockEntity? getByBarcodeSync(String barcode) {
    return getByIndexSync(r'barcode', [barcode]);
  }

  Future<bool> deleteByBarcode(String barcode) {
    return deleteByIndex(r'barcode', [barcode]);
  }

  bool deleteByBarcodeSync(String barcode) {
    return deleteByIndexSync(r'barcode', [barcode]);
  }

  Future<List<StockEntity?>> getAllByBarcode(List<String> barcodeValues) {
    final values = barcodeValues.map((e) => [e]).toList();
    return getAllByIndex(r'barcode', values);
  }

  List<StockEntity?> getAllByBarcodeSync(List<String> barcodeValues) {
    final values = barcodeValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'barcode', values);
  }

  Future<int> deleteAllByBarcode(List<String> barcodeValues) {
    final values = barcodeValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'barcode', values);
  }

  int deleteAllByBarcodeSync(List<String> barcodeValues) {
    final values = barcodeValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'barcode', values);
  }

  Future<Id> putByBarcode(StockEntity object) {
    return putByIndex(r'barcode', object);
  }

  Id putByBarcodeSync(StockEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'barcode', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBarcode(List<StockEntity> objects) {
    return putAllByIndex(r'barcode', objects);
  }

  List<Id> putAllByBarcodeSync(List<StockEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'barcode', objects, saveLinks: saveLinks);
  }
}

extension StockEntityQueryWhereSort
    on QueryBuilder<StockEntity, StockEntity, QWhere> {
  QueryBuilder<StockEntity, StockEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StockEntityQueryWhere
    on QueryBuilder<StockEntity, StockEntity, QWhereClause> {
  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> barcodeEqualTo(
      String barcode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'barcode',
        value: [barcode],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> barcodeNotEqualTo(
      String barcode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'barcode',
              lower: [],
              upper: [barcode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'barcode',
              lower: [barcode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'barcode',
              lower: [barcode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'barcode',
              lower: [],
              upper: [barcode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> productNameEqualTo(
      String productName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'productName',
        value: [productName],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause>
      productNameNotEqualTo(String productName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productName',
              lower: [],
              upper: [productName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productName',
              lower: [productName],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productName',
              lower: [productName],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productName',
              lower: [],
              upper: [productName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause>
      productBarcodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'productBarcode',
        value: [null],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause>
      productBarcodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'productBarcode',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause>
      productBarcodeEqualTo(String? productBarcode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'productBarcode',
        value: [productBarcode],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause>
      productBarcodeNotEqualTo(String? productBarcode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productBarcode',
              lower: [],
              upper: [productBarcode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productBarcode',
              lower: [productBarcode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productBarcode',
              lower: [productBarcode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productBarcode',
              lower: [],
              upper: [productBarcode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> grnCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'grnCode',
        value: [null],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> grnCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'grnCode',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> grnCodeEqualTo(
      String? grnCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'grnCode',
        value: [grnCode],
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterWhereClause> grnCodeNotEqualTo(
      String? grnCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'grnCode',
              lower: [],
              upper: [grnCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'grnCode',
              lower: [grnCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'grnCode',
              lower: [grnCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'grnCode',
              lower: [],
              upper: [grnCode],
              includeUpper: false,
            ));
      }
    });
  }
}

extension StockEntityQueryFilter
    on QueryBuilder<StockEntity, StockEntity, QFilterCondition> {
  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      availableQuantityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'availableQuantity',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      availableQuantityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'availableQuantity',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      availableQuantityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'availableQuantity',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      availableQuantityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'availableQuantity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> barcodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'barcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      barcodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'barcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> barcodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'barcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> barcodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'barcode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      barcodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'barcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> barcodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'barcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> barcodeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'barcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> barcodeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'barcode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      barcodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'barcode',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      barcodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'barcode',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      buyingPriceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'buyingPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      buyingPriceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'buyingPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      buyingPriceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'buyingPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      buyingPriceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'buyingPrice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      expiryDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'expiryDate',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      expiryDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'expiryDate',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      expiryDateEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiryDate',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      expiryDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiryDate',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      expiryDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiryDate',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      expiryDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiryDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      grnCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'grnCode',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      grnCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'grnCode',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> grnCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'grnCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      grnCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'grnCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> grnCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'grnCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> grnCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'grnCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      grnCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'grnCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> grnCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'grnCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> grnCodeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'grnCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> grnCodeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'grnCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      grnCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'grnCode',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      grnCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'grnCode',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      initialQuantityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'initialQuantity',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      initialQuantityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'initialQuantity',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      initialQuantityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'initialQuantity',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      initialQuantityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'initialQuantity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      maxDiscountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxDiscount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      maxDiscountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxDiscount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      maxDiscountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxDiscount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      maxDiscountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxDiscount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'productBarcode',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'productBarcode',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productBarcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'productBarcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'productBarcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'productBarcode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'productBarcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'productBarcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'productBarcode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'productBarcode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productBarcode',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productBarcodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'productBarcode',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'productName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'productName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'productName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productName',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      productNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'productName',
        value: '',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      sellingPriceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sellingPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      sellingPriceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sellingPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      sellingPriceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sellingPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      sellingPriceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sellingPrice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> statusEqualTo(
      StockEntityStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      statusGreaterThan(
    StockEntityStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> statusLessThan(
    StockEntityStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition> statusBetween(
    StockEntityStatus lower,
    StockEntityStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterFilterCondition>
      updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StockEntityQueryObject
    on QueryBuilder<StockEntity, StockEntity, QFilterCondition> {}

extension StockEntityQueryLinks
    on QueryBuilder<StockEntity, StockEntity, QFilterCondition> {}

extension StockEntityQuerySortBy
    on QueryBuilder<StockEntity, StockEntity, QSortBy> {
  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      sortByAvailableQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableQuantity', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      sortByAvailableQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableQuantity', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByBuyingPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buyingPrice', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByBuyingPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buyingPrice', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByExpiryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryDate', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByExpiryDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryDate', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByGrnCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grnCode', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByGrnCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grnCode', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByInitialQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'initialQuantity', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      sortByInitialQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'initialQuantity', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByMaxDiscount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxDiscount', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByMaxDiscountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxDiscount', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByProductBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productBarcode', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      sortByProductBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productBarcode', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByProductName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByProductNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortBySellingPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellingPrice', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      sortBySellingPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellingPrice', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension StockEntityQuerySortThenBy
    on QueryBuilder<StockEntity, StockEntity, QSortThenBy> {
  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      thenByAvailableQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableQuantity', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      thenByAvailableQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableQuantity', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByBuyingPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buyingPrice', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByBuyingPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buyingPrice', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByExpiryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryDate', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByExpiryDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryDate', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByGrnCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grnCode', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByGrnCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grnCode', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByInitialQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'initialQuantity', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      thenByInitialQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'initialQuantity', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByMaxDiscount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxDiscount', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByMaxDiscountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxDiscount', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByProductBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productBarcode', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      thenByProductBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productBarcode', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByProductName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByProductNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productName', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenBySellingPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellingPrice', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy>
      thenBySellingPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellingPrice', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension StockEntityQueryWhereDistinct
    on QueryBuilder<StockEntity, StockEntity, QDistinct> {
  QueryBuilder<StockEntity, StockEntity, QDistinct>
      distinctByAvailableQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'availableQuantity');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByBarcode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'barcode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByBuyingPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'buyingPrice');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByExpiryDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiryDate');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByGrnCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'grnCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct>
      distinctByInitialQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'initialQuantity');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByMaxDiscount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxDiscount');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByProductBarcode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productBarcode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByProductName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctBySellingPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sellingPrice');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<StockEntity, StockEntity, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension StockEntityQueryProperty
    on QueryBuilder<StockEntity, StockEntity, QQueryProperty> {
  QueryBuilder<StockEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StockEntity, int, QQueryOperations> availableQuantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'availableQuantity');
    });
  }

  QueryBuilder<StockEntity, String, QQueryOperations> barcodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'barcode');
    });
  }

  QueryBuilder<StockEntity, double, QQueryOperations> buyingPriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'buyingPrice');
    });
  }

  QueryBuilder<StockEntity, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StockEntity, DateTime?, QQueryOperations> expiryDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiryDate');
    });
  }

  QueryBuilder<StockEntity, String?, QQueryOperations> grnCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'grnCode');
    });
  }

  QueryBuilder<StockEntity, int, QQueryOperations> initialQuantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'initialQuantity');
    });
  }

  QueryBuilder<StockEntity, double, QQueryOperations> maxDiscountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxDiscount');
    });
  }

  QueryBuilder<StockEntity, String?, QQueryOperations>
      productBarcodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productBarcode');
    });
  }

  QueryBuilder<StockEntity, String, QQueryOperations> productNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productName');
    });
  }

  QueryBuilder<StockEntity, double, QQueryOperations> sellingPriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sellingPrice');
    });
  }

  QueryBuilder<StockEntity, StockEntityStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<StockEntity, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
