;;;; mediaimport.lisp
(defpackage #:mediaimport.utils
  (:use #:cl #:cl-annot.class))

(in-package #:mediaimport.utils)
(annot:enable-annot-syntax)


(defconstant +regex-escape-chars+
  '(#\\
    #\*
    #\+
    #\?
    #\|
    #\{
    #\}
    #\[
    #\]
    #\(
    #\)
    #\^
    #\$
    #\.
    #\#
    #\Space)
  "List of special characters to be escaped in file mask")


@export
(defun interleave (list1 list2)
  "Interleaves 2 lists.
Example:
=> (interleave '(1 2 3) '(-1 -2 -3))
(1 -1 2 -2 3 -3)"
  (let ((parity t)
        (result (copy-list list1)))
    (merge 'list result list2
           (lambda (x y)
             (declare (ignore x) (ignore y))
             (setf parity (not parity))))
    result))

@export
(defun partition (seq predicate)
  "Split the SEQ of type list by PREDICATE, returning the VALUES,
where 1st value is the list of elements for which PREDICATE is true,
and 2nd is the list of elements for which PREDICATE is false."
  (let ((pos (remove-if-not predicate seq))
        (neg (delete-if predicate seq)))
    (values pos neg)))
    


@export
(defun file-size (filename)
  "Return the size of the file with the name FILENAME in bytes"
  (with-open-file (in filename :element-type '(unsigned-byte 8))
    (file-length in)))

@export
(defun read-header (filename size)
  "Read SIZE bytes from the file FILENAME. If the file size is less than SIZE,
read up to the size of file"
  (let ((elt-type '(unsigned-byte 8)))
    (with-open-file (in filename :element-type elt-type)
      (let* ((fsize (file-length in))
             (buffer (make-array (min size fsize) :element-type elt-type)))
        (read-sequence buffer in)
        buffer))))


@export
(defun directory-exists-p (dirname)
  "Return T if DIRNAME specifies an existing directory.
Suppress all errors and returns NIL otherwise"
  (handler-case
      (fad:directory-exists-p dirname)
    (error (err) nil)))


@export
(defclass duplicate-finder () ((items :initarg :items)
                               (key :initarg :key :initform #'identity)
                               (nonuniques-table :initform
                                                 (make-hash-table :test #'equal)))
  (:documentation "Find duplicates in the array/list. Creates a hash table with
frequencies of encountered items to use later to determine if the item has a
duplicate in the array/list"))
                               

(defmethod initialize-instance :after ((self duplicate-finder) &key)
  "Constructor. Create an internal hash-table containing frequencies of
occurences of items in the array/list"
  (with-slots (items key nonuniques-table) self
    (map nil (lambda (x)
            (let* ((arg (funcall key x))
                   (ht-value (gethash arg nonuniques-table)))
              (if (not ht-value)
                  (setf (gethash arg nonuniques-table) 1)
                  (incf (gethash arg nonuniques-table)))))
          items)))
   

@export
(defmethod duplicate-p ((self duplicate-finder) arg)
  "Returns t if the ARG was encountered more than once"
  (with-slots (nonuniques-table) self
    (multiple-value-bind (value result)
        (gethash arg nonuniques-table)
      (values (if (not result) nil (> value 1)) result))))


@export
(defun wildcard-to-regex (wildcard &key case-sensitive-p)
  "Convert file wildcards to regular expressions. By default the regular
expression is case insensitive. This is regulated by keyword argument
CASE-SENSITIVE-P
Example:
=> (mediaimport.utils:wildcard-to-regex \"Photo*.jpg\") 
\"(?i)^Photo.*\\\\.jpg$\""
  ;; special case: *.* means * in reality
  (if (string= wildcard "*.*")
      ".*"
      ;; otherwise do processing
      (let ((regex
             (make-array (+ 8 (length wildcard))
                         :element-type
                         'lw:bmp-char
                         :fill-pointer 0
                         :adjustable t)))
        (unless case-sensitive-p
          (vector-push-extend #\( regex)
          (vector-push-extend #\? regex)
          (vector-push-extend #\i regex)
          (vector-push-extend #\) regex))
        (vector-push-extend #\^ regex)
        (loop for char across wildcard do
              (cond ((eq char #\*)
                     (progn
                       (vector-push-extend #\. regex)
                       (vector-push-extend #\* regex)))
                    ((eq char #\?)
                     (vector-push-extend #\. regex))
                    ((find char +regex-escape-chars+)
                     (progn
                       (vector-push-extend #\\ regex)
                       (vector-push-extend char regex)))
                    (t (vector-push-extend char regex))))
        (vector-push-extend #\$ regex)
        regex)))


    
